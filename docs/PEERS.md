# Peers tab

What the pills and table cells on the Peers tab mean and where they come from.
The tab is fed live by the node, which reports **one entry per live
connection** — a peer reachable both over a relay and directly appears with
both paths.

## Your node — reachability pill

Two facts joined with `·`: whether the node can be dialled from outside, and by
what route peers actually get in. The second part reports evidence, never a
prediction.

| Pill | Meaning |
| ---- | ------- |
| `Public · via <source>` | A dial-back from outside succeeded. The suffix names what produced the verdict (e.g. `autonat`, `upnp`). |
| `Behind NAT · hole punched` | Dial-back fails, but a live connection carries the DCUtR flag — a peer has reached this node directly through the NAT after a relay introduction. |
| `Behind NAT · relay reserved` | Dial-back fails; the node holds a reservation on a relay, so peers reach it over a circuit. Circuits may later be upgraded by DCUtR — that is only known once it happens, so this is not a claim that relaying is the ceiling. |
| `Behind NAT · outbound only` | Not dialable and holding no reservation: nothing can reach this node; it can only open connections itself. |
| `Reachability unknown` | No verdict yet — too few peers have reported an address and no dial-back has completed. A real state, not a loading state: announcing is deferred until it resolves. |
| `No update for Ns` | The live stream has gone quiet; the header is showing the last snapshot. |

## Table columns

| Column | Derived from |
| ------ | ------------ |
| CONN | ✓ when at least one live connection exists. Otherwise a Connect action, enabled only if the routing table holds an address to dial. |
| DHT | ✓ when the peer is in our Kademlia routing table. A row can have DHT without CONN (routing-only: known but not connected) and vice versa. |
| PATH | The primary connection's path and direction — see below. `—` for routing-only peers. |
| RTT | Latest ping round-trip, shared by all of a peer's connections. |
| ROLE | Configured role, then observed DHT role — see below. |
| ADDRESS | Outbound: the multiaddr we dialled. Inbound: the remote end of the socket as we see it — expect the peer's ephemeral/NAT source port, not its listen port. |

## PATH values

The collapsed row shows the *primary* connection (direct preferred over
relayed); expanding the row lists every path individually.

| Label | Meaning |
| ----- | ------- |
| `direct` | A plain connection — no relay involved, no NAT traversal needed (or the peer's NAT already had a mapping open, e.g. via UPnP or port reuse). |
| `p2p` | A direct connection that DCUtR built by hole punching: direct *despite* both ends being behind NAT. Distinguished from `direct` because "the NAT was traversed" and "no NAT in the way" are different facts. |
| `relay` | A circuit through a relay; traffic flows via the relay. Outbound relay: we reached a peer we cannot dial directly. Inbound relay: a peer reached us through a relay we hold a reservation with. |

| Arrow | Meaning |
| ----- | ------- |
| `→` | Outbound — we initiated the connection. |
| `←` | Inbound — the peer initiated it. |
| `⇄` | The peer holds connections both ways (collapsed row only); neither side depends on the other being reachable. Which path went which way is in the expanded panel. |

## ROLE values

Configuration and observation are independent axes, so both can show at once
(`bootstrap · client`).

| Value | Meaning |
| ----- | ------- |
| `bootstrap` | One of the node's configured bootstrap peers. |
| `trusted relay` | One of the node's configured trusted relays. |
| `client` | Observed via identify: queries the DHT but does not serve it — never a routing hop. Common for hivemind/Python peers and for nodes only reachable via a relay. |
| `—` | No configured role and serving the DHT normally. |
