report_timing -file vivslack.rpt -sort_by group -max_paths 100 -path_type summary
report_timing -file vivsetup.rpt -max_paths 100 -slack_less_than 3.0
report_timing -file vivhold.rpt  -max_paths 100 -slack_less_than 3.0 -hold
exit

