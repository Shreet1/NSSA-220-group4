def parse_filtered_file(path):
    """
    Reads the filtered node text file and will return a list of packet dictionaries,
    each containing the fields needed for metrics:

        time, src, dst, type, seq, total_len, frame, payload, ttl
    """
    ETHERNET_HEADER_LEN = 14
    IP_HEADER_LEN = 20
    ICMP_HEADER_LEN = 8

    packets = []

    with open(path, "r") as f:
        for line in f:
            # Only process ping request/reply lines
            if "(ping) request" not in line and "(ping) reply" not in line:
                continue

            parts = line.split()
            if len(parts) < 10:
                continue

            try:
                time = float(parts[1])
                src_ip = parts[2]
                dst_ip = parts[3]
                frame_bytes = int(parts[5])

                # Determine ICMP type
                if "request" in parts:
                    icmp_type = 8
                elif "reply" in parts:
                    icmp_type = 0
                else:
                    continue

                # Extract seq= and ttl=
                seq = None
                ttl = None
                for token in parts:
                    if token.startswith("seq="):
                        # seq=91/23296, -> take 91
                        raw = token.split("=", 1)[1]
                        raw = raw.split("/", 1)[0]
                        raw = raw.rstrip(",")
                        seq = int(raw)

                    if token.startswith("ttl="):
                        raw = token.split("=", 1)[1]
                        raw = raw.rstrip(",)")
                        ttl = int(raw)

                if seq is None or ttl is None:
                    continue

                # Calculate IP total length & payload
                ip_total_length = frame_bytes - ETHERNET_HEADER_LEN
                payload = ip_total_length - IP_HEADER_LEN - ICMP_HEADER_LEN
                if payload < 0:
                    payload = 0

                packets.append({
                    "time": time,
                    "src": src_ip,
                    "dst": dst_ip,
                    "type": icmp_type,
                    "seq": seq,
                    "total_len": ip_total_length,
                    "frame": frame_bytes,
                    "payload": payload,
                    "ttl": ttl
                })

            except Exception:
                continue

    return packets
