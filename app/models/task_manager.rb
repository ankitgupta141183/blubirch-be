class TaskManager < ApplicationRecord

  enum status: { started: 1, completed: 2, failed: 3 }, _prefix: true

  def self.create_task(task_name)
    create({
      status: 'started',
      task_name: task_name,
      run_at: Time.now
    })
  end

  def complete_task(result = :ok)
    status = result == :ok ? 'completed' : 'failed'

    update({
      status: status,
      time_taken: completion_time,
      result: result.to_s
    })
  end

  def completion_time
    Time.now.to_i - run_at.to_i
  end
end
