#使用ruby为shell提供json操作支持
require 'json'

content=ARGV.at(0)
action=ARGV.at(1)
key=ARGV.at(2)
value=ARGV.at(3)

if content == nil or content == ""
    content = "{}"
end
jsonObj = JSON.parse(content)
case action
    when "get"
        if jsonObj != nil and key != nil
            puts "#{jsonObj[key]}"
        end
    when "set"
        if jsonObj == nil 
            jsonObj = Hash.new
        end
        if key != nil
            if value != nil
                jsonObj[key] = value
            else
                jsonObj.delete(key)
            end
        end
        puts "#{jsonObj.to_json}"
    when "print"
        puts "#{jsonObj}";
end