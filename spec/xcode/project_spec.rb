# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

require 'spec_helper'

describe Xcode::Project do
  before :all do
    contents = File.read(Rails.root.join('spec', 'fixtures', 'project.pbxproj'))
    @project = Xcode::Project.new(contents)
  end

  it "should properly parse PBXFileReferences" do
    expect(@project.files.size).to eql(845)
    expect(@project.files['22BF021216AB57E100F5B384']).not_to be_nil
    expect(@project.files['22BF021216AB57E100F5B384'].name).to eql('CrashReporterDemoViewController.m')
    expect(@project.files['22BF021216AB57E100F5B384'].path).to eql('CrashReporterDemoViewController.m')
    expect(@project.files['22BF021216AB57E100F5B384'].full_path).to eql('/../Vendor/PLCrashReporter/contrib/php-crashreporter-demo/Classes/CrashReporterDemoViewController.m')
    expect(@project.files['22BF021216AB57E100F5B384'].source_tree).to eql(:group)
    expect(@project.files['22BF021216AB57E100F5B384'].parent.path).to eql('Classes')
  end

  it "should properly parse PBXGroups" do
    expect(@project.groups.size).to eql(96)
    expect(@project.groups['22BF024516AB57E100F5B384']).not_to be_nil
    expect(@project.groups['22BF024516AB57E100F5B384'].path).to eql('Resources')
    expect(@project.groups['22BF024516AB57E100F5B384'].full_path).to eql('/../Vendor/PLCrashReporter/Resources')
    expect(@project.groups['22BF024516AB57E100F5B384'].source_tree).to eql(:group)
    expect(@project.groups['22BF024516AB57E100F5B384'].parent.path).to eql('PLCrashReporter')
  end

  it "should properly parse PBXBuildFiles" do
    expect(@project.build_files.size).to eql(34)
    expect(@project.build_files['221AAD3B16B0CEAB00628F6E']).not_to be_nil
    expect(@project.build_files['221AAD3B16B0CEAB00628F6E'].file.full_path).to eql('/SquashCocoa iOS Tester/STAppDelegate.m')
  end

  it "should properly parse PBXSourcesBuildPhases" do
    expect(@project.source_phases.size).to eql(3)
    expect(@project.source_phases['22BF06EF16AB5A6100F5B384']).not_to be_nil
    expect(@project.source_phases['22BF06EF16AB5A6100F5B384'].files.map(&:file).map(&:name)).
        to eql(%w(SquashCocoa.m SCFunctions.m SCOccurrence.m Reachability.m ISO8601DateFormatter.m))
  end

  it "should properly parse PBXNativeTargets" do
    expect(@project.targets.size).to eql(3)
    expect(@project.targets['22C1EA7016AB4C1000FC6E94']).not_to be_nil
    expect(@project.targets['22C1EA7016AB4C1000FC6E94'].name).to eql('SquashCocoa iOS')
    expect(@project.targets['22C1EA7016AB4C1000FC6E94'].source_phases.size).to eql(1)
    expect(@project.targets['22C1EA7016AB4C1000FC6E94'].all_paths).
        to eql(['/SquashCocoa iOS/../../Source/SCFunctions.m',
                '/SquashCocoa iOS/../../Source/SCOccurrence.m',
                '/SquashCocoa iOS/../../Source/SquashCocoa.m',
                '/SquashCocoa iOS/../../Source/Utility/Reachability.m',
                '/../Vendor/ISO8601DateFormatter/ISO8601DateFormatter.m'])
  end
end
