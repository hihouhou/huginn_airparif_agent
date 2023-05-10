module Agents
  class AirparifAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Airparif Agent interacts with Airparif API.

      `debug` is used for verbose mode.

      `apikey` is needed for authenticated endpoint.

      `insee` is needed for the city ( see `https://www.dcode.fr/code-commune-insee`).

      `type` is for the wanted action like planned_pollution_indices.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "75101": [
              {
                "date": "2021-01-15",
                "no2": "Bon",
                "o3": "Mauvais",
                "pm10": "Moyen",
                "pm25": "Dégradé",
                "so2": "Bon",
                "indice": "Dégradé"
              },
              {
                "date": "2021-01-16",
                "no2": "Bon",
                "o3": "Mauvais",
                "pm10": "Moyen",
                "pm25": "Dégradé",
                "so2": "Bon",
                "indice": "Dégradé"
              }
            ]
          }
    MD

    def default_options
      {
        'apikey' => '',
        'insee' => '',
        'type' => 'planned_pollution_indices',
        'debug' => 'false',
        'emit_events' => 'true',
        'expected_receive_period_in_days' => '2',
      }
    end

    form_configurable :apikey, type: :string
    form_configurable :insee, type: :string
    form_configurable :debug, type: :boolean
    form_configurable :emit_events, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :type, type: :array, values: ['planned_pollution_indices', 'version']
    def validate_options
      errors.add(:base, "type has invalid value: should be 'planned_pollution_indices', 'version'") if interpolated['type'].present? && !%w(planned_pollution_indices version).include?(interpolated['type'])

      unless options['insee'].present? || !['planned_pollution_indices'].include?(options['type'])
        errors.add(:base, "insee is a required field")
      end

      unless options['apikey'].present? || !['planned_pollution_indices'].include?(options['type'])
        errors.add(:base, "apikey is a required field")
      end

      if options.has_key?('emit_events') && boolify(options['emit_events']).nil?
        errors.add(:base, "if provided, emit_events must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def receive(incoming_events)
      incoming_events.each do |event|
        interpolate_with(event) do
          log event
          trigger_action
        end
      end
    end

    def check
      trigger_action
    end

    private

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def version()

      uri = URI.parse("https://api.airparif.asso.fr/version")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)
      payload = JSON.parse(response.body)

      if !memory['version']
        if interpolated['emit_events'] == 'true'
          create_event payload: payload
        end
      else
        last_status = memory['version']
        if payload != last_status
          create_event payload: response.body
        end
      end  
      memory['version'] = payload

    end

    def planned_pollution_indices()

      uri = URI.parse("https://api.airparif.asso.fr/indices/prevision/commune?insee=#{interpolated['insee']}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"
      request["X-Api-Key"] = interpolated['apikey']
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
      
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log_curl_output(response.code,response.body)
      payload = JSON.parse(response.body)

      if interpolated['emit_events'] == 'true'
        create_event payload: payload
      end

    end

    def trigger_action

      case interpolated['type']
      when "planned_pollution_indices"
        planned_pollution_indices()
      when "version"
        version()
      else
        log "Error: type has an invalid value (#{interpolated['type']})"
      end
    end
  end
end
