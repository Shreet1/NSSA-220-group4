#!/usr/bin/python3

node_ips = {
    "Node1": "192.168.100.1",
    "Node2": "192.168.100.2",
    "Node3": "192.168.200.1",
    "Node4": "192.168.200.2"
}

# Read parsed txt file and add lines to packet dictionary
def read_parsed_summary_file(filename):
    packets = []
    with open(filename) as f:
        lines = f.readlines()[1:]
        for line in lines:
            parts = line.split()
            packet = {
                "time": float(parts[0]),  
                "src": parts[1],          
                "dst": parts[2],          
                "type": int(parts[3]),    
                "seq": int(parts[4]),     
                "total_len": int(parts[5]),
                "frame": int(parts[6]),   
                "payload": int(parts[7]), 
                "ttl": int(parts[8])      
            }
            packets.append(packet)
    return packets

# Compute 13 metrics per node
def compute(node_name, packets):
    node_ip = node_ips[node_name]
    requests_sent = []
    requests_rec = []
    replies_sent = []
    replies_rec = []

    for p in packets:
        if p["type"] == 8 and p["src"] == node_ip:
            requests_sent.append(p)
        elif p["type"] == 8 and p["dst"] == node_ip:
            requests_rec.append(p)
        elif p["type"] == 0 and p["src"] == node_ip:
            replies_sent.append(p)
        elif p["type"] == 0 and p["dst"] == node_ip:
            replies_rec.append(p)

    # Counts total number packages
    total_req_sent = len(requests_sent)
    total_req_rec = len(requests_rec)
    total_rep_sent = len(replies_sent)
    total_rep_rec = len(replies_rec)

    total_req_b_sent = 0
    total_req_b_rec = 0
    total_req_p_sent = 0
    total_req_p_rec = 0

    # Calculate bytes and payload for requests sent
    for p in requests_sent:
        total_req_b_sent += p["frame"]
        total_req_p_sent += p["payload"]

    # Calculate bytes and payload for requests recieved 
    for p in requests_rec:
        total_req_b_rec += p["frame"]
        total_req_p_rec += p["payload"]

    # Calculate average RTT (microseconds)
    seq_to_req_time = {(p["seq"], p["dst"]): p["time"] for p in requests_sent}
    rtts = []
    for rep in replies_rec:
        key = (rep["seq"], rep["src"])
        if key in seq_to_req_time:
            rtt = (rep["time"] - seq_to_req_time[key]) * 1000
            rtts.append(rtt)
    avg_rtt = round(sum(rtts)/len(rtts), 2) if rtts else 0

    # Calculate Echo Request throughput and goodput (kB/sec)
    if requests_sent and replies_rec:
        total_time_sec = sum(rtts)/1000 if rtts else 0
    else:
        total_time_sec = 0
    throughput = round(total_req_b_sent / 1024 / total_time_sec, 2) if total_time_sec else 0
    goodput = round(total_req_p_sent / 1024 / total_time_sec, 2) if total_time_sec else 0

    # Calculate average reply delay (microseconds)
    seq_src_to_req_time = {}
    for p in requests_rec:
        seq_src_to_req_time[(p["seq"], p["src"])] = p["time"]
    reply_delays = []
    for rep in replies_sent:
        key = (rep["seq"], rep["dst"])
        if key in seq_src_to_req_time:
            delay = (rep["time"] - seq_src_to_req_time[key]) * 1_000_000
            reply_delays.append(delay)

    avg_reply_delay = round(sum(reply_delays)/len(reply_delays), 2) if reply_delays else 0

    # Calculate average hop count
    if replies_rec:
        starting_ttl = max(p["ttl"] for p in replies_rec)
        num_hops = [starting_ttl - p["ttl"] + 1 for p in replies_rec]
        avg_hops = round(sum(num_hops)/len(num_hops), 2)
    else:
        avg_hops = 0

    # Return metrics as dictionary
    return {
        "Echo Requests Sent": total_req_sent,
        "Echo Requests Received": total_req_rec,
        "Echo Replies Sent": total_rep_sent,
        "Echo Replies Received": total_rep_rec,
        "Echo Request Bytes Sent (bytes)": total_req_b_sent,
        "Echo Request Data Sent (bytes)": total_req_p_sent,
        "Echo Request Bytes Received (bytes)": total_req_b_rec,
        "Echo Request Data Received (bytes)": total_req_p_rec,
        "Average RTT (ms)": avg_rtt,
        "Echo Request Throughput (kB/sec)": throughput,
        "Echo Request Goodput (kB/sec)": goodput,
        "Average Reply Delay (us)": avg_reply_delay,
        "Average Echo Request Hop Count": avg_hops
}

# Write to metrics file
def write_metrics(all_metrics, filename="metrics.txt"):
    with open(filename, "w") as f:
        for node, metrics in all_metrics.items():
            f.write(f"{node.replace('Node', 'Node ')}\n\n")
            f.write("Echo Requests Sent,Echo Requests Received,Echo Replies Sent,Echo Replies Received\n")
            f.write(f"{metrics['Echo Requests Sent']},{metrics['Echo Requests Received']},{metrics['Echo Replies Sent']},{metrics['Echo Replies Received']}\n")
            f.write("Echo Request Bytes Sent (bytes),Echo Request Data Sent (bytes)\n")
            f.write(f"{metrics['Echo Request Bytes Sent (bytes)']},{metrics['Echo Request Data Sent (bytes)']}\n")
            f.write("Echo Request Bytes Received (bytes),Echo Request Data Received (bytes)\n")
            f.write(f"{metrics['Echo Request Bytes Received (bytes)']},{metrics['Echo Request Data Received (bytes)']}\n\n")
            f.write(f"Average RTT (ms),{metrics['Average RTT (ms)']}\n")
            f.write(f"Echo Request Throughput (kB/sec),{metrics['Echo Request Throughput (kB/sec)']}\n")
            f.write(f"Echo Request Goodput (kB/sec),{metrics['Echo Request Goodput (kB/sec)']}\n")
            f.write(f"Average Reply Delay (us),{metrics['Average Reply Delay (us)']}\n")
            f.write(f"Average Echo Request Hop Count,{metrics['Average Echo Request Hop Count']}\n\n")
    print(f"File created: {filename}")

# Process all nodes
all_metrics = {}
for node in node_ips:
    packets = read_parsed_summary_file(f"{node}_parsed_summary.txt")
    all_metrics[node] = compute(node, packets)
write_metrics(all_metrics)
