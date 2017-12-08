class LinebotController < ApplicationController
  require 'line/bot'
  protect_from_forgery :except => [:callback]
  
  def get_callback
    render plain: "hello"
  end


  def callback
    body = request.body.read


    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event['type']
      when "message"
        message = {type: 'text' ,text: 'テストメッセージ'}
        message = confirm_message(event)
        user_id = event['source']['userId']
        client.push_message(user_id,message)

      when "follow"
        follow(event)

      when "unfollow"
        unfollow(event)

      when "postback"
        postback(event)
      end
    }
  end



  #友達登録されたときの処理
  def follow(event)
    user_id = event['source']['userId']
    res = get_profile(user_id)
    puts res['displayName']
    user = User.new(name: res['displayName'],line_id: user_id)
    if user.save
      message = {type: "text",
                 text: "友達登録ありがとう!!\n使い方はこちらを参照"
      }
      client.push_message(user_id,message)
    else 
      message = {type: "text",
                 text: "エラー"}
      client.push_message(user_id,message)
    end
  end

  #ブロック時の処理
  def unfollow(event)
    user_id = event['source']['userId']
    client.push_message(user_id,{type: "text",text: "byby"})
    user = User.find_by_line_id(user_id)
    if user 
      user.destroy
    end
  end

  def postback(event)
    postback_data = event['postback']['data'].split("\n")
    user_id = event['source']['userId']
    case postback_data[0]
    when "登録キャンセル"
      message = {type: "text", text: "キャンセルしました"}
      client.push_message(user_id,message)

    when "本として登録"
      client.push_message(user_id,{type: "text",text: "#{postback_data[1]}を登録"})

    when "作者として登録"
      client.push_message(user_id,{type: "text",text: "#{postback_data[1]}を登録"})
    end
  end

  def client
    @clinet ||= Line::Bot::Client.new{ |config| 
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def get_profile(user_id)
    response = client.get_profile(user_id)
    case response
    when Net::HTTPSuccess then
      contact = JSON.parse(response.body)
      # p contact['displayName']
      # p contact['pictureUrl']
      # p contact['statusMessage']
    else
      p "#{response.code} #{response.body}"
    end
  end


  def confirm_message(event)
    {
      "type": "template",
      "altText": "this is a buttons template",
      "template": {
        "type": "buttons",
        "text": "Please select",
        "actions": [
          {
            "type": "postback",
            "label": "本として登録",
            "data": "本として登録\n#{event['message']['text']}"
          },
          {
            "type": "postback",
            "label": "作者として登録",
            "data": "作者として登録\n#{event['message']['text']}"
          },
          {
            "type": "postback",
            "label": "登録キャンセル",
            "data": "登録キャンセル"
          }
        ]
      }
    }
  end
end
