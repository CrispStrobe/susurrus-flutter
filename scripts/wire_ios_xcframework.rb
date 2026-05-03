#!/usr/bin/env ruby
# Wire ios/Frameworks/crispasr.xcframework into the Runner target so
# `flutter build ios` produces a Runner.app that includes the framework
# and can dlopen it via `crispasr.framework/crispasr` from Dart FFI.
#
# Idempotent: re-running this script after `pod install` regenerates
# the Pods linkage, but our entries persist as long as the file
# references remain in pbxproj.
#
# Run from repo root: ruby scripts/wire_ios_xcframework.rb

require 'xcodeproj'

REPO_ROOT  = File.expand_path('..', __dir__)
PROJECT    = File.join(REPO_ROOT, 'ios', 'Runner.xcodeproj')
XCFW_PATH  = 'Frameworks/crispasr.xcframework'
XCFW_ABS   = File.join(REPO_ROOT, 'ios', XCFW_PATH)

abort "missing #{XCFW_ABS} — run scripts/build_ios_xcframework.sh first" \
  unless File.exist?(XCFW_ABS)

project = Xcodeproj::Project.open(PROJECT)
target  = project.targets.find { |t| t.name == 'Runner' } or
  abort 'Runner target not found'

# 1. File reference. Group "Frameworks" lives at the project root in
#    standard Flutter templates; create it if missing.
fw_group = project.main_group['Frameworks'] ||
           project.main_group.new_group('Frameworks')

ref = fw_group.files.find { |f| f.path == XCFW_PATH }
unless ref
  ref = fw_group.new_file(XCFW_PATH)
  ref.last_known_file_type = 'wrapper.xcframework'
end

# 2. Link Binary With Libraries — the linker resolves the framework's
#    symbols against the placeholder so dyld can bind them at launch.
link_phase = target.frameworks_build_phase
unless link_phase.files_references.include?(ref)
  link_phase.add_file_reference(ref)
end

# 3. Embed Frameworks (Copy Files build phase). dst_subfolder_spec=10
#    means "Frameworks" (i.e. <app>.app/Frameworks/). Xcode picks the
#    matching slice from the xcframework at build time.
embed_phase = target.copy_files_build_phases.find do |p|
  p.dst_subfolder_spec == '10' && p.name&.include?('Embed')
end
unless embed_phase
  embed_phase = target.new_copy_files_build_phase('Embed Frameworks')
  embed_phase.dst_subfolder_spec = '10'
  embed_phase.dst_path = ''
end

embed_file = embed_phase.files.find { |bf| bf.file_ref == ref }
unless embed_file
  embed_file = embed_phase.add_file_reference(ref)
end
embed_file.settings = { 'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy] }

# 4. FRAMEWORK_SEARCH_PATHS so the linker finds the .xcframework at
#    build time. $(PROJECT_DIR) resolves to the ios/ directory.
target.build_configurations.each do |config|
  paths = config.build_settings['FRAMEWORK_SEARCH_PATHS']
  paths = case paths
          when nil then ['$(inherited)']
          when String then [paths]
          else paths
          end
  needed = '$(PROJECT_DIR)/Frameworks'
  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = paths | [needed]
end

# 5. Disable user script sandboxing for plugins that touch the
#    framework dir (Xcode 15+ sandboxing default is too strict).
target.build_configurations.each do |config|
  config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
end

project.save

puts 'wired crispasr.xcframework into Runner target:'
puts "  - file reference in Frameworks group"
puts "  - linked into binary"
puts "  - embedded with CodeSignOnCopy"
puts "  - FRAMEWORK_SEARCH_PATHS includes $(PROJECT_DIR)/Frameworks"
