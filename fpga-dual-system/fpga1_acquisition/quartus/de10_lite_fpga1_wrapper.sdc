# Board clock constraint for the DE10-Lite 50 MHz oscillator.
create_clock -name {clock_50_i} -period 20.000 [get_ports {clock_50_i}]

derive_clock_uncertainty
