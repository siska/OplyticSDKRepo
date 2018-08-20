#
# Be sure to run `pod lib lint OplyticSDKRepo.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OplyticSDKRepo'
  s.version          = '0.1.1'
  s.summary          = 'Oplytic provides precise attribution and reattribution to affiliate partners.'
  s.swift_version    = '4.1'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Oplytic tracks installs, actions and purchases within mobile apps providing precise attribution and reattribution to affiliate partners.
                       DESC

  s.homepage         = 'https://github.com/siska/OplyticSDKRepo'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'siska' => 'rsiska1@gmail.com' }
  s.source           = { :git => 'https://github.com/siska/OplyticSDKRepo.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'OplyticSDKRepo/Classes/**/*'
  
  # s.resource_bundles = {
  #   'OplyticSDKRepo' => ['OplyticSDKRepo/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'UIKit', 'AdSupport'
  s.library    = 'sqlite3'
  # s.dependency 'AFNetworking', '~> 2.3'
end
