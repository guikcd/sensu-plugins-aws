#! /usr/bin/env ruby
#
# check-trustedadvisor-asg-resources
#
#
# DESCRIPTION:
#   This plugin uses Trusted Advisor API to perform check for
#   autoscaling group resources. Trigger 'critical' on sensu for ASG
#   that are not 'Green'.
#
#   IAM requires AWSSupportAccess policy enabled.
#
#   https://aws.amazon.com/premiumsupport/ta-faqs/
#
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk-v1
#   gem: sensu-plugin
#
# USAGE:
#  ./check-trustedadvisor-asg-resources.rb -l {en|ja}
#
# NOTES:
#
# LICENSE:
#   Guillaume Delacour <guillaume.delacour@oxalide.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'sensu-plugins-aws'
require 'aws-sdk'

class CheckTrustedAdvisorAsgResources < Sensu::Plugin::Check::CLI
  include Common
  option :aws_language,
         short: '-l AWS_LANGUAGE',
         long: '--aws-language AWS_LANGUAGE',
         description: "ISO 639-1 language code to be used when querying Trusted Advisor API. Only 'en' and 'ja' supported for now",
         default: 'en'

  def run
    # The Support endpoint seems to only available in us-east-1 region
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/Support.html
    aws_support = Aws::Support::Client.new(region: 'us-east-1')

    asg_resources_msg = []

    begin
      # service limit check
      # Perform a refresh to make sure the API result is not stale.
      # all Check IDs: https://aws.amazon.com/premiumsupport/ta-iam/
      aws_support.refresh_trusted_advisor_check(check_id: '8CNsSllI5v')
      asg = aws_support.describe_trusted_advisor_check_result(check_id: '8CNsSllI5v', language: config[:aws_language])

      asg[:result][:flagged_resources].each do |asgr|
        # Data structure will be as follow
        # ["<region>", "<asg>", "<launch_configuration>", "<resource_type>", "<resource_name>", "<status>", "<reason>"]
        asg_region, asg_asg, asg_launch_configuration, asg_resource_type, asg_resource_name, asg_status, asg_reason= asgr[:metadata]

        next if asg_status == 'Green'
        asg_usage = 0 if asg_usage.nil?

        asg_msg = "#{asg_asg} (#{asg_region}) launch configuration #{asg_launch_configuration} need missing #{asg_resource_type} #{asg_resource_name}: #{asg_reason}"
        asg_resources_msg.push(asg_msg)
      end
    rescue => e
      unknown "An error occurred processing AWS TrustedAdvisor API: #{e.message}"
    end

    if asg_resources_msg.empty?
      ok
    else
      critical("ASG resources not found: #{asg_resources_msg.join(', ')}")
    end
  end
end
