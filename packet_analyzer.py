from filter_packets import *
from packet_parser import *
from compute_metrics import *

filter()

# Parse raw filtered files and produce parsed summary files
node1_packets = parse_filtered_file('Node1_filtered.txt', 'Node1_parsed_summary.txt')
node2_packets = parse_filtered_file('Node2_filtered.txt', 'Node2_parsed_summary.txt')
node3_packets = parse_filtered_file('Node3_filtered.txt', 'Node3_parsed_summary.txt')
node4_packets = parse_filtered_file('Node4_filtered.txt', 'Node4_parsed_summary.txt')

# Read the parsed summary files for metrics
node1_summary = read_parsed_summary_file('Node1_parsed_summary.txt')
node2_summary = read_parsed_summary_file('Node2_parsed_summary.txt')
node3_summary = read_parsed_summary_file('Node3_parsed_summary.txt')
node4_summary = read_parsed_summary_file('Node4_parsed_summary.txt')

compute('Node1', node1_summary)
compute('Node2', node2_summary)
compute('Node3', node3_summary)
compute('Node4', node4_summary)