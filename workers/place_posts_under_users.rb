require "esa"
require "sidekiq"
require "sidekiq-cron"
require "dotenv"

Dotenv.load

class PlacePostsUnderUsersWorker
  def perform
    posts.each do |post|
      move_and_comment(
        post_number: post["number"],
        name: post["name"],
        screen_name: post["created_by"]["screen_name"],
      )
    end
  end

  private

  def client
    @client ||= Esa::Client.new(
      access_token: ENV["ESA_API_TOKEN"],
      current_team: ENV["ESA_TEAM"],
    )
  end

  def posts
    posts = []
    page = 1

    result = client.posts(q: "on:/", page: page).body
    next_page = result["next_page"]
    posts << result["posts"]

    while !next_page.nil?
      page += 1
      result = client.posts(q: "on:/", page: page).body
      posts << result["posts"]

      next_page = result["next_page"]
    end

    posts.flatten
  end

  def move_and_comment(post_number:, name:, screen_name:)
    move(post_number: post_number, name: name, screen_name: screen_name)
    comment(post_number: post_number, screen_name: screen_name)
  end

  def move(post_number:, name:, screen_name:)
    client.update_post(post_number, name: "Users/#{screen_name}/#{name}", updated_by: "esa_bot")
  end

  def comment(post_number:, screen_name:)
    client.create_comment(post_number, body_md: "@#{screen_name} :esa:", user: "esa_bot")
  end
end
