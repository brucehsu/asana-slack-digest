require_relative "config/const"
require_relative "helpers"
require 'asana'
require 'json'

client = Asana::Client.new do |c|
  c.authentication :access_token, ASANA_ACCESS_TOKEN
end


workspaces = client.workspaces.find_all

workspace = workspaces.select { |wkspace| wkspace.name == ASANA_WORKSPACE }.first
projects = client.projects.find_by_workspace(workspace: workspace.id)

# If you're generating for multiple workspaces:
#
# projects = workspaces.map do |workspace|
#   client.projects.find_by_workspace(workspace: workspace.id)
# end.flatten

tasks_by_assignee = {}

teams = client.teams.find_by_organization(organization: workspace.id)
team = teams.select { |t| t.name == ASANA_TEAM }.first

users = team.users.take(team.users.size)
users.each do |user|
  tasks_by_assignee[user.id] = {
    name: user.name,
    completed: [],
    doing: [],
    blocked: []
  }
end

# Fetch tasks for each project
projects.each do |project|
  project_tasks = client.tasks.find_by_project(projectId: project.id, per_page: ASANA_PER_PAGE)
  project_tasks = project_tasks.take(project_tasks.size)

  # Use semicolon to determine if the task is a section
  # and eliminate empty task
  project_tasks.select! do |task|
    task.name[-1] != ':' and not task.name.empty?
  end

  project_tasks.each do |task|
    task = client.tasks.find_by_id(task.id)
    task = format_task task

    unless task.nil?
      assignee_id = task[:assignee][:id]
      tasks_by_assignee[assignee_id] ||= {}
      tasks_by_assignee[assignee_id][:name] ||= task[:assignee][:name]

      if task[:completed]
        tasks_by_assignee[assignee_id][:completed] << task
      else
        tasks_by_assignee[assignee_id][task[:status].downcase.to_sym] << task
      end
    end
  end
end

puts "Finish generating data, now posting..."

client = Faraday.new(url: SLACK_WEBHOOK_BASE) do |f|
  f.request  :url_encoded             # form-encode POST params
  f.response :logger                  # log requests to STDOUT
  f.adapter  Faraday.default_adapter  # make requests with Net::HTTP
end

client.post do |req|
  req.url SLACK_INCOMING_WEBHOOK
  req.headers['Content-type'] = 'application/json'
  req.body = {
    channel: SLACK_CHANNEL,
    username: SLACK_USERNAME,
    text: generate_message(tasks_by_assignee),
    icon_emoji: SLACK_EMOJI
  }.to_json
end

puts "Daily digest posted to channel: #{SLACK_CHANNEL}"