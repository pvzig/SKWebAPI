Pod::Spec.new do |s|
  s.name             = "SKWebAPI"
  s.version          = "4.0.4"
  s.summary          = "A Swift library to help make requests to the Slack Web API"
  s.homepage         = "https://github.com/SlackKit/SKWebAPI"
  s.license          = 'MIT'
  s.author           = { "Peter Zignego" => "peter@launchsoft.co" }
  s.source           = { :git => "https://github.com/SlackKit/SKWebAPI.git", :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/pvzig'
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.tvos.deployment_target = '9.0'
  s.requires_arc = true
  s.source_files = 'Sources/*.swift'  
  s.frameworks = 'Foundation'
  s.dependency 'SKCore'
end
