#!/usr/bin/env ruby
# Create the iOS ShareExtension target in ios/Runner.xcodeproj and wire it
# into the Runner app so `flutter build ios` produces a Runner.app with
# Runner.app/PlugIns/ShareExtension.appex.
#
# The Swift / Info.plist / entitlements source files are checked in at
# ios/ShareExtension/; this script does only the project.pbxproj edits
# that Xcode would otherwise do via the "File → New → Target → Share
# Extension" wizard:
#
#   1. PBXNativeTarget `ShareExtension`, product type app extension
#   2. Sources / Resources / Frameworks build phases
#   3. File refs for ShareViewController.swift + Info.plist + entitlements
#   4. Build configurations (Debug / Release / Profile) mirroring Runner,
#      with PRODUCT_BUNDLE_IDENTIFIER = <runner-bundle-id>.ShareExtension
#   5. Runner's "Embed App Extensions" CopyFiles phase referencing the
#      extension's product
#
# App Group capability + Code Signing Entitlements are set per-configuration
# via build settings. The shared entitlements file at
# ios/ShareExtension/ShareExtension.entitlements already declares the
# group.com.crispstrobe.crisperweaver group.
#
# Idempotent: re-running detects existing target / file refs and skips.
# After running, do `cd ios && pod install` so receive_sharing_intent's
# pod surfaces in the extension's link list, then build.
#
# Run from repo root: ruby scripts/wire_ios_share_extension.rb

require 'xcodeproj'

REPO_ROOT       = File.expand_path('..', __dir__)
PROJECT_PATH    = File.join(REPO_ROOT, 'ios', 'Runner.xcodeproj')
SHARE_EXT_DIR   = File.join(REPO_ROOT, 'ios', 'ShareExtension')
EXT_NAME        = 'ShareExtension'
APP_GROUP       = 'group.com.crispstrobe.crisperweaver'

%w[
  ShareViewController.swift
  RSIShareViewController.swift
  Info.plist
  ShareExtension.entitlements
].each do |f|
  abort "missing #{File.join(SHARE_EXT_DIR, f)}" unless File.exist?(File.join(SHARE_EXT_DIR, f))
end

project = Xcodeproj::Project.open(PROJECT_PATH)
runner  = project.targets.find { |t| t.name == 'Runner' } or
  abort 'Runner target not found in Runner.xcodeproj'

# 1. PBXNativeTarget for the extension.
ext = project.targets.find { |t| t.name == EXT_NAME }
if ext
  puts "#{EXT_NAME} target already exists — re-wiring file refs + phases idempotently"
else
  ext = project.new_target(
    :app_extension,
    EXT_NAME,
    :ios,
    runner.deployment_target || '13.0',
  )
  puts "created PBXNativeTarget #{EXT_NAME}"
end

# 2. Group `ShareExtension` under the project's main group, holding the
#    file refs that show up in the navigator.
group = project.main_group[EXT_NAME] || project.main_group.new_group(EXT_NAME, EXT_NAME)

# Helper: find-or-create a file ref under `group` with path `name` (relative
# to the group itself, which is anchored at ios/ShareExtension/).
def find_or_add_file(group, name)
  existing = group.files.find { |f| f.path == name }
  return existing if existing
  group.new_reference(name)
end

src_ref         = find_or_add_file(group, 'ShareViewController.swift')
rsi_ref         = find_or_add_file(group, 'RSIShareViewController.swift')
info_ref        = find_or_add_file(group, 'Info.plist')
entitlements_ref = find_or_add_file(group, 'ShareExtension.entitlements')

# 3. Sources build phase: ShareViewController.swift +
#    RSIShareViewController.swift (vendored extension-safe parts of
#    receive_sharing_intent — see that file's header).
src_phase = ext.source_build_phase
[src_ref, rsi_ref].each do |ref|
  src_phase.add_file_reference(ref) unless src_phase.files_references.include?(ref)
end

# 4. Frameworks build phase: AppKit-style extension frameworks are linked
#    automatically; nothing to add here beyond what xcodeproj seeds.

# 5. Build configurations. The xcodeproj gem already created Debug/Release
#    when we made the target, but its default settings don't know our
#    bundle id stem / app group entitlements file. Mirror Runner's
#    PRODUCT_BUNDLE_IDENTIFIER as <runner-id>.ShareExtension and point
#    CODE_SIGN_ENTITLEMENTS at the checked-in plist.
runner_bundle_id = runner.build_configurations.first&.build_settings
                         &.[]('PRODUCT_BUNDLE_IDENTIFIER') ||
                   'com.crispstrobe.crisperweaver'
ext_bundle_id = "#{runner_bundle_id}.#{EXT_NAME}"
runner_dev_team = runner.build_configurations.first&.build_settings
                        &.[]('DEVELOPMENT_TEAM')

ext.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = ext_bundle_id
  s['PRODUCT_NAME']              = '$(TARGET_NAME)'
  s['INFOPLIST_FILE']            = 'ShareExtension/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS']    = 'ShareExtension/ShareExtension.entitlements'
  s['SWIFT_VERSION']             = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  s['SKIP_INSTALL']              = 'NO'
  s['LD_RUNPATH_SEARCH_PATHS']   = ['$(inherited)', '@executable_path/Frameworks',
                                    '@executable_path/../../Frameworks']
  s['MARKETING_VERSION']         = '$(MARKETING_VERSION)'
  s['CURRENT_PROJECT_VERSION']   = '$(FLUTTER_BUILD_NUMBER)'
  s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  s['DEVELOPMENT_TEAM']          = runner_dev_team if runner_dev_team
  # Extension is strict-extension-safe — RSIShareViewController is
  # vendored locally (see ios/ShareExtension/RSIShareViewController.swift)
  # so no `addApplicationDelegate` (or any other extension-unavailable
  # API) is in the link graph. Leave APPLICATION_EXTENSION_API_ONLY at
  # its default YES.
end

# Make sure the extension target has Debug / Release / Profile to mirror
# Runner's configuration list — Flutter uses Profile for profile-mode
# builds and Xcode will error out if it's missing on the embed target.
runner_configs = runner.build_configurations.map(&:name)
ext_configs    = ext.build_configurations.map(&:name)
(runner_configs - ext_configs).each do |missing|
  ext.add_build_configuration(missing, missing.downcase.include?('release') ? 'Release' : 'Debug')
  puts "added missing build configuration `#{missing}` to #{EXT_NAME}"
end
project.build_configurations.map(&:name).each do |proj_cfg|
  next if ext.build_configurations.any? { |c| c.name == proj_cfg }
  ext.add_build_configuration(proj_cfg, proj_cfg.downcase.include?('release') ? 'Release' : 'Debug')
end

# Re-apply the per-config block above to any newly-added configurations so
# they share the same bundle id / entitlements / deployment target.
ext.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] ||= ext_bundle_id
  s['INFOPLIST_FILE']            ||= 'ShareExtension/Info.plist'
  s['CODE_SIGN_ENTITLEMENTS']    ||= 'ShareExtension/ShareExtension.entitlements'
  s['SWIFT_VERSION']             ||= '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] ||= '13.0'
  s['ENABLE_USER_SCRIPT_SANDBOXING'] ||= 'NO'
end

# 6. Embed App Extensions phase on Runner. dst_subfolder_spec=13 means
#    "PlugIns", i.e. the extension lands at Runner.app/PlugIns/<ext>.appex.
#
# Phase ORDER matters here. If we leave the new phase at the end of
# Runner's build phase list (xcodeproj's default for new phases), the
# Xcode "new build system" finds a cycle:
#     Embed App Extensions → [CP] Copy Pods Resources → Thin Binary
#     → ProcessInfoPlist → PlugIns/ShareExtension.appex → Embed App
#     Extensions
# (Thin Binary's input is Runner.app, which transitively includes
# PlugIns/, which the copy phase is supposed to populate.)
#
# Apple's own template puts "Embed App Extensions" immediately after
# "Frameworks" and BEFORE the Pods script phases. We mirror that.
embed_phase = runner.copy_files_build_phases.find do |p|
  p.dst_subfolder_spec == '13'
end
unless embed_phase
  embed_phase = runner.new_copy_files_build_phase('Embed App Extensions')
  embed_phase.dst_subfolder_spec = '13'
  embed_phase.dst_path = ''
  embed_phase.name = 'Embed App Extensions'
end

# Move the Embed App Extensions phase to immediately after the
# Frameworks phase (matching Xcode's template), so the cycle above
# doesn't form. This is a no-op if the phase is already there.
frameworks_idx = runner.build_phases.index do |p|
  p.isa == 'PBXFrameworksBuildPhase'
end
embed_idx = runner.build_phases.index(embed_phase)
if frameworks_idx && embed_idx && embed_idx != frameworks_idx + 1
  runner.build_phases.delete(embed_phase)
  runner.build_phases.insert(frameworks_idx + 1, embed_phase)
end

ext_product_ref = ext.product_reference
existing_embed  = embed_phase.files.find { |bf| bf.file_ref == ext_product_ref }
unless existing_embed
  build_file = embed_phase.add_file_reference(ext_product_ref)
  build_file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy] }
end

# 7. Runner depends on the extension so Xcode builds it first in a
#    workspace-level build.
existing_dep = runner.dependencies.find { |d| d.target == ext }
unless existing_dep
  runner.add_dependency(ext)
end

# 8. Wire Runner's CODE_SIGN_ENTITLEMENTS to its existing
#    Runner/Runner.entitlements file. The file is checked in and
#    already declares the App Group, but the Flutter template
#    Xcode project never set CODE_SIGN_ENTITLEMENTS for Runner —
#    so without this, Runner ships with NO App Group entitlement
#    and the receive-side of the share hand-off never sees what
#    the extension wrote. (Diagnosed by `codesign -d --entitlements
#    - Runner.app` after a real codesigned build.)
runner.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] ||= 'Runner/Runner.entitlements'
end

# 9. SystemCapabilities → App Groups on both targets. This is what
#    surfaces as the "App Groups" checkbox in Signing & Capabilities;
#    Xcode reads it when generating provisioning profiles, and Apple's
#    Developer Portal cross-checks against it during automatic
#    profile sync. The actual entitlement is read from the .entitlements
#    files (pointed at by CODE_SIGN_ENTITLEMENTS above), so this
#    block exists purely to keep Xcode UI + auto-signing happy.
project.root_object.attributes['TargetAttributes'] ||= {}
[runner, ext].each do |t|
  ta = project.root_object.attributes['TargetAttributes'][t.uuid] ||= {}
  caps = ta['SystemCapabilities'] ||= {}
  caps['com.apple.ApplicationGroups.iOS'] ||= { 'enabled' => 1 }
end

project.save

puts ''
puts 'wired ShareExtension into Runner.xcodeproj:'
puts "  - PBXNativeTarget #{EXT_NAME} (app extension)"
puts "    bundle id: #{ext_bundle_id}"
puts '    entitlements: ShareExtension/ShareExtension.entitlements'
puts '    info.plist:   ShareExtension/Info.plist'
puts '  - Sources build phase: ShareViewController.swift'
puts '  - Runner: Embed App Extensions phase referencing the .appex'
puts '  - Runner: depends on ShareExtension'
puts ''
puts 'next steps:'
puts '  1. cd ios && pod install'
puts '     (so the extension picks up receive_sharing_intent\'s pod)'
puts "  2. Open Runner.xcworkspace once and confirm the App Groups capability"
puts "     (#{APP_GROUP}) is enabled on BOTH targets in Signing & Capabilities."
puts '  3. flutter build ios   # or build to a device from Xcode'
puts ''
puts 'verify by Sharing a Voice Memos recording → CrisperWeaver should appear.'
