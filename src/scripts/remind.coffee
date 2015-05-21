# Description:
#   Remind to someone something
#
# Commands:
#   hubot remind to <user> in #s|m|h|d to <something to remind> - remind to someone something in a given time eg 5m for five minutes
#   hubot what will you remind - Show active reminders
#   hubot what are your reminders - Show active reminders
#   hubot forget|rm reminder <id> - Remove a given reminder

cronJob = require('cron').CronJob
moment = require('moment')

JOBS = {}

createNewJob = (robot, pattern, user, message) ->
  id = Math.floor(Math.random() * 1000000) while !id? || JOBS[id]
  job = registerNewJob robot, id, pattern, user, message
  robot.brain.data.things[id] = job.serialize()
  id

registerNewJobFromBrain = (robot, id, pattern, user, message) ->
  registerNewJob(robot, id, pattern, user, message)

registerNewJob = (robot, id, pattern, user, message) ->
  job = new Job(id, pattern, user, message)
  job.start(robot)
  JOBS[id] = job

unregisterJob = (robot, id)->
  if JOBS[id]
    JOBS[id].stop()
    delete robot.brain.data.things[id]
    delete JOBS[id]
    return yes
  no

handleNewJob = (robot, msg, user, pattern, message) ->
    id = createNewJob robot, pattern, user, message
    msg.send "Got it! I will remind to #{user.name} at #{pattern}"

module.exports = (robot) ->
  robot.brain.data.things or= {}

  # The module is loaded right now
  robot.brain.on 'loaded', ->
    for own id, job of robot.brain.data.things
      console.log id
      registerNewJobFromBrain robot, id, job...

  robot.respond /what (will you remind|are your reminders)/i, (msg) ->
    text = ''
    for id, job of JOBS
      room = job.user.reply_to || job.user.room
      if room == msg.message.user.reply_to or room == msg.message.user.room
        text += "#{id}: @#{room} to \"#{job.message} at #{job.pattern}\"\n"
    if text.length > 0
      msg.send text
    else
      msg.send "Nothing to remind, isn't it?"

  robot.respond /(forget|rm|remove) reminder (\d+)/i, (msg) ->
    reqId = msg.match[2]
    for id, job of JOBS
      if (reqId == id)
        if unregisterJob(robot, reqId)
          msg.send "Reminder #{id} sleep with the fishes..."
        else
          msg.send "i can't forget it, maybe i need a headshrinker"

  robot.respond /remind (.*) in (\d+)([s|m|h|d]) to (.*)/i, (msg) ->
    name = msg.match[1]
    at = msg.match[2]
    time = msg.match[3]
    something = msg.match[4]

    if /^me$/i.test(name.trim())
      users = [msg.message.user]
    else
      name = name.replace 'to ', ''
      users = robot.brain.usersForFuzzyName(name)

    if users.length is 1
      switch time
        when 's' then timeWord = 'second'
        when 'm' then timeWord = 'minute'
        when 'h' then timeWord = 'hour'
        when 'd' then timeWord = 'day'

      handleNewJob robot, msg, users[0], moment().add(at, timeWord).toDate(), something
    else if users.length > 1
      msg.send "Be more specific, I know #{users.length} people " +
        "named like that: #{(user.name for user in users).join(", ")}"
    else
      msg.send "#{name}? Never heard of 'em"



class Job
  constructor: (id, pattern, user, message) ->
    @id = id
    @pattern = pattern
    # cloning user because adapter may touch it later
    clonedUser = {}
    clonedUser[k] = v for k,v of user
    @user = clonedUser
    @message = message

  start: (robot) ->
    @cronjob = new cronJob(@pattern, =>
      @sendMessage robot, ->
      unregisterJob robot, @id
    )
    @cronjob.start()

  stop: ->
    @cronjob.stop()

  serialize: ->
    [@pattern, @user, @message]

  sendMessage: (robot) ->
    envelope = user: @user, room: @user.room
    message = @message
    if @user.mention_name
      message = "Hey @#{envelope.user.mention_name} remember: " + @message
    else
      message = "Hey @#{envelope.user.name} remember: " + @message
    robot.send envelope, message

