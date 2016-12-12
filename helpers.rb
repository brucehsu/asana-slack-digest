# You can implement formatting that suit your tasks here
def format_task(task)
  status = task.custom_fields.select { |f| f['name'] == 'Status' }.first['enum_value']
  status = status.nil? ? '' : status['name']
  if (task.completed and Time.parse(task.completed_at) > (Date.today - 1).to_time) || status == 'Doing'
    task = {
      name: "[#{task.memberships.first['project']['name']}]  #{task.name}",
      assignee: {
        id: task.assignee['id'],
        name: task.assignee['name']
      },
      completed: task.completed,
      status: task.completed ? 'Done' : 'Doing',
    }
    return task
  end

  nil
end

# You can implement digest generation that suit your tasks here
def generate_message(tasks)
  msg = "_* Daily Standup Digest *_\n"

  tasks.each do |assignee_id, value|
    msg << "\n*#{ value[:name] }*\n"

    msg << "# Done\n"
    value[:completed].each do |completed|
      msg << "- #{completed[:name]}\n"
    end unless value[:completed].empty?

    msg << "# Doing\n"
    value[:doing].each do |doing|
      msg << "- #{doing[:name]}\n"
    end unless value[:doing].empty?
  end

  msg
end