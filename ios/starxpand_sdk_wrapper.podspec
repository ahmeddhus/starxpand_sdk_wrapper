#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint starxpand_sdk_wrapper.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'starxpand_sdk_wrapper'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for Star Micronics printers using StarXpand SDK.'
  s.description      = <<-DESC
A Flutter plugin that wraps the Star Micronics StarXpand SDK for iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/orioletech/starxpand_sdk_wrapper'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'OrioleTech' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'

  # Vendor the XCFramework
  s.vendored_frameworks = 'Frameworks/StarIO10.xcframework'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'starxpand_sdk_wrapper_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
