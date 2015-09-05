Pod::Spec.new do |spec|
  spec.name = 'SAMCache'
  spec.version = '0.3.2'
  spec.summary = 'Simple in memory and on disk cache.'
  spec.description  = 'Simple in memory and on disk cache for iOS and Mac OS X.'
  spec.homepage = 'https://github.com/soffes/SAMCache'
  spec.author = { 'Sam Soffes' => 'sam@soff.es' }
  spec.source = { :git => 'https://github.com/soffes/SSCache.git', :tag => "v#{spec.version}" }
  spec.license = { :type => 'MIT', :file => 'LICENSE' }

  spec.platform = :osx, '7.0'
  spec.ios.frameworks = 'Foundation', 'UIKit'
  spec.ios.source_files = ['SAMCache/SAMCache.{h,m}', 'SAMCache/SAMCache+Image.{h,m}']

  spec.platform = :watchos, '2.0'
  spec.watchos.frameworks = 'Foundation', 'WatchKit'
  spec.watchos.source_files = ['SAMCache/SAMCache.{h,m}', 'SAMCache/SAMCache+Image.{h,m}']

  spec.platform = :osx, '10.9'
  spec.osx.frameworks = 'Foundation'
  spec.osx.source_files = 'SAMCache/SAMCache.{h,m}'
end
