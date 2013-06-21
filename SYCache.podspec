Pod::Spec.new do |s|
  s.name         = 'SYCache'
  s.version      = '1.0.0'
  s.summary      = 'Simple in memory and on disk cache for iOS and Mac OS X'
  s.homepage     = 'https://github.com/soffes/SYCache'
  s.author       = { 'Sam Soffes' => 'sam@soff.es' }
  s.source       = { :git => 'https://github.com/soffes/SYCache.git' }
  s.description  = 'Simple in memory and on disk cache.'
  s.source_files = 'SYCache.h', 'SYCache.m'
  s.requires_arc = true
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
end