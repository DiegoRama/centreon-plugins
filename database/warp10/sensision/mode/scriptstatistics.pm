#
# Copyright 2019 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package database::warp10::sensision::mode::scriptstatistics;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::common::monitoring::openmetrics::scrape;

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'functions', type => 1, cb_prefix_output => 'prefix_output',
          message_multiple => 'All functions statistics are ok' },
    ];
    
    $self->{maps_counters}->{global} = [
        { label => 'time-total', nlabel => 'time.total.microseconds', set => {
                key_values => [ { name => 'time' } ],
                output_template => 'Time Spent: %d us',
                perfdatas => [
                    { value => 'time_absolute', template => '%d',
                      min => 0, unit => 'us' },
                ],
            }
        },
        { label => 'requests', nlabel => 'requests.count', set => {
                key_values => [ { name => 'requests' } ],
                output_template => 'Requests: %d',
                perfdatas => [
                    { value => 'requests_absolute', template => '%d',
                      min => 0 },
                ],
            }
        },
        { label => 'ops', nlabel => 'ops.count', set => {
                key_values => [ { name => 'ops' } ],
                output_template => 'Ops: %d',
                perfdatas => [
                    { value => 'ops_absolute', template => '%d',
                      min => 0 },
                ],
            }
        },
        { label => 'errors', nlabel => 'errors.count', set => {
                key_values => [ { name => 'errors' } ],
                output_template => 'Errors: %d',
                perfdatas => [
                    { value => 'errors_absolute', template => '%d',
                      min => 0 },
                ],
            }
        },
        { label => 'bootstrap-loads', nlabel => 'bootstrap.loads.count', set => {
                key_values => [ { name => 'bootstrap_loads' } ],
                output_template => 'Bootstrap Loads: %d',
                perfdatas => [
                    { value => 'bootstrap_loads_absolute', template => '%d',
                      min => 0 },
                ],
            }
        },
    ];
    $self->{maps_counters}->{functions} = [
        { label => 'time', nlabel => 'function.time.microseconds', set => {
                key_values => [ { name => 'time' }, { name => 'display' } ],
                output_template => 'Time Spent: %d us',
                perfdatas => [
                    { value => 'time_absolute', template => '%d',
                      min => 0, unit => 'us', label_extra_instance => 1, instance_use => 'display_absolute' },
                ],
            }
        },
        { label => 'uses', nlabel => 'function.uses.count', set => {
                key_values => [ { name => 'count' }, { name => 'display' } ],
                output_template => 'Uses: %d',
                perfdatas => [
                    { value => 'count_absolute', template => '%d',
                      min => 0, label_extra_instance => 1, instance_use => 'display_absolute' },
                ],
            }
        },
    ];
}

sub prefix_output {
    my ($self, %options) = @_;
    
    return "Function '" . $options{instance_value}->{display} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {
        "filter-name:s" => { name => 'filter_name' },
    });
   
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{functions} = {};
    $self->{metrics} = centreon::common::monitoring::openmetrics::scrape::parse(%options);

    $self->{global} = {
        time => $self->{metrics}->{'warp.script.time.us'}->{data}[0]->{value},
        requests => $self->{metrics}->{'warp.script.requests'}->{data}[0]->{value},
        ops => $self->{metrics}->{'warp.script.ops'}->{data}[0]->{value},
        errors => $self->{metrics}->{'warp.script.errors'}->{data}[0]->{value},
        bootstrap_loads => $self->{metrics}->{'warp.script.bootstrap.loads'}->{data}[0]->{value},
    };

    foreach my $function (@{$self->{metrics}->{'warp.script.function.count'}->{data}}) {
        $self->{functions}->{$function->{dimensions}->{function}}->{count} = $function->{value};
        $self->{functions}->{$function->{dimensions}->{function}}->{display} = $function->{dimensions}->{function};
    }
    foreach my $function (@{$self->{metrics}->{'warp.script.function.time.us'}->{data}}) {
        $self->{functions}->{$function->{dimensions}->{function}}->{time} = $function->{value};
        $self->{functions}->{$function->{dimensions}->{function}}->{display} = $function->{dimensions}->{function};
    }

    foreach (keys %{$self->{functions}}) {
        delete $self->{functions}->{$_} if (defined($self->{option_results}->{filter_name}) &&
            $self->{option_results}->{filter_name} ne '' &&
            $_ !~ /$self->{option_results}->{filter_name}/);
    }
    
    if (scalar(keys %{$self->{functions}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No functions found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check script and functions statistics.

=over 8

=item B<--filter-name>

Filter function name (can be a regexp).

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^time$|uses'

=item B<--warning-*>

Threshold warning.
Can be: 'time-total', 'requests', 'ops',
'errors', 'bootstrap-loads', 'time', 'uses'.

=item B<--critical-*>

Threshold critical.
Can be: 'time-total', 'requests', 'ops',
'errors', 'bootstrap-loads', 'time', 'uses'.

=back

=cut
