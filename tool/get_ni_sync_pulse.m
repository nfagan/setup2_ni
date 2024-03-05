function is_pos = get_ni_sync_pulse(ni_sync_channel)

validateattributes( ni_sync_channel, {'double'}, {'vector'}, mfilename, 'ni_trace' );
is_pos = ni_sync_channel > 0.99;

end