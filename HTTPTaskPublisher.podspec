#
# Be sure to run `pod lib lint HTTPTaskPublisher.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'HTTPTaskPublisher'
  s.version          = '0.1.0'
  s.summary          = 'Swift Publisher for HTTP request'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  Swift DataTaskPublisher, DownloadTaskPublisher and UploadTaskPublisher Wrapper for HTTP request
                       DESC

  s.homepage         = 'https://github.com/hainayanda/HTTPTaskPublisher'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'hainayanda' => 'hainayanda@outlook.com' }
  s.source           = { :git => 'https://github.com/hainayanda/HTTPTaskPublisher.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '13.0'
  s.swift_versions = '5.5'

  s.source_files = 'HTTPTaskPublisher/Classes/**/*'
  
  # s.resource_bundles = {
  #   'HTTPTaskPublisher' => ['HTTPTaskPublisher/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  s.dependency 'CombineAsync', '~> 1.0'
end
