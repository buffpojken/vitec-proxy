require 'resque-retry'
require 'resque/failure/redis'

Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

require './updater'
require './fetcher'
require 'resque/tasks'
require 'resque/scheduler/tasks'
