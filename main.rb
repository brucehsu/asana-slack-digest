require_relative "config/const"
require_relative "helpers"
require 'asana'
require 'json'
require 'celluloid'
require 'celluloid/future'

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

task_futures = []

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
    task_futures << Celluloid::Future.new { client.tasks.find_by_id(task.id) }
  end
end

task_futures.each do |future|
  task = future.value
  puts "Phase 2: #{(Time.now - start)}s"
  start = Time.now
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

puts "Daily digest posted to channel: #{SLACK_CHANNEL}"