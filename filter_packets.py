#!/usr/bin/python3

import os
import dpkt
import socket

def read_file(filename):
    # function that reads through the .txt file and sections contents off by packet
    sections = []
    current_section = []
    section_count = 0

    with open(filename, 'r') as file:
        for line in file:
            #statements in the loop section packets by tracking blank lines in the file
            if line.strip() == '':
                section_count += 1
            current_section.append(line.rstrip('\n'))

            if section_count == 2:
                sections.append(current_section)
                current_section = []
                section_count = 0

        # adds last packet to list since there is no blank line at the end
        if current_section:
            sections.append(current_section)

    return sections


def filter():
    for i in range(1, 5):
        #for loop filtering every node text file
        node_txt = f"Node{i}.txt"
        packet_list = read_file(node_txt)

        icmp_dict = {}
        index = 0

        # reading pcap w/ dpkt library
        with open(f"Node{i}.pcap", 'rb') as f:
            pcap = dpkt.pcap.Reader(f)

            for ts, buf in pcap:
                try:
                    eth = dpkt.ethernet.Ethernet(buf)
                    if isinstance(eth.data, dpkt.ip.IP):
                        ip = eth.data

                        # Check if it's ICMP (protocol number 1)
                        if ip.p == dpkt.ip.IP_PROTO_ICMP:
                            if index < len(packet_list):
                                icmp_dict[index] = packet_list[index]
                except Exception:
                    # skip malformed packets
                    pass

                index += 1

        # write filtered sections
        with open(f"Node{i}_filtered.txt", 'w') as new_file:
            for section in icmp_dict.values():
                for line in section:
                    new_file.write(line + "\n")


filter()