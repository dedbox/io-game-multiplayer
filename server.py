#!/usr/bin/env python

"""A multiplayer game server."""

import asyncio
from select import select
from socket import socket, AF_INET, SOCK_DGRAM, SOL_SOCKET, SO_REUSEADDR, SO_BROADCAST
from random import uniform
from numpy import array
from numpy.linalg import norm

CLOCK_FREQ = 60                 # Hz
CLOCK_PERIOD = 1 / CLOCK_FREQ   # s

def normalized(vec):
    """Returns a unit vector pointing in the direction of the given vector."""
    vec_len = norm(vec)
    return vec if vec_len == 0 else vec / vec_len

class Agent:
    """A mobile agent."""

    def __init__(self, x0, x1):
        self.pos = array([float(x0), float(x1)])  # px
        self.speed = 10                           # px / s
        self.state = ('IDLE',)

    def move_to(self, to_x, to_y):
        """Start moving to the given coordinates."""
        self.state = ('MOVE', array([float(to_x), float(to_y)]))
        print('MOVE {:.2f} {:.2f}'.format(to_x, to_y))

    def stop(self):
        """Stop moving."""
        self.state = ('IDLE',)

    def process(self, delta):
        """Advance the simulation."""
        if self.state[0] == 'MOVE':
            self.process_move(delta)

    def process_move(self, delta):
        """Move toward the target."""
        x_i = self.pos
        x_f = self.state[1]
        v_x_f = x_f - x_i
        v_x = normalized(v_x_f) * self.speed * delta
        self.pos += v_x if norm(v_x) < norm(v_x_f) else v_x_f
        if norm(v_x_f) < 0.01:
            self.stop()

def simulate(agent):
    """A test simulation."""
    agent.move_to(0, 50)

    loop = asyncio.get_event_loop()
    theta0 = loop.time()
    theta = theta0 + CLOCK_PERIOD

    def tick():
        """Advance the simulation."""
        nonlocal theta

        agent.process(CLOCK_PERIOD)

        if agent.state[0] == 'IDLE':
            to_x = uniform(0, 100)
            to_y = uniform(0, 100)
            agent.move_to(to_x, to_y)

        loop.call_at(theta, tick)
        theta += CLOCK_PERIOD

    tick()

#     def _report():
#         d_theta = theta - theta0
#         pos_x, pos_y = agent.pos
#         buf = ' '.join([str(x) for x in (i, d_theta, pos_x, pos_y)])
#         sock.sendto(buf.encode(), (UDP_HOST, UDP_PORT))
#         print('TICK {:06d} {:.2f} ({:3.2f},{:3.2f})'.format(i, d_theta, pos_x, pos_y))

#     def tick():
#         """Advance the clock."""
#         nonlocal theta, i
#         _report()

#         agent.process(CLOCK_PERIOD)

#         theta += CLOCK_PERIOD
#         i += 1

#         if agent.state[0] == 'IDLE':
#             target_x = uniform(0, 100)
#             target_y = uniform(0, 100)
#             agent.move_to(target_x, target_y)
#             print('-- MOVE ({:3.2f},{:3.2f})'.format(target_x, target_y))

#         loop.call_at(theta, tick)

#     loop.call_at(theta, tick)

#     # clients = {}

#     # def serve():
#     #     while sock.get_available

#     # loop.call_at(theta, serve)

# def old_main():
#     """The main function."""
#     loop = asyncio.get_event_loop()
#     sock = socket(AF_INET, SOCK_DGRAM, 0)
#     sock.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
#     sock.setblocking(False)
#     loop.call_soon(run, loop, sock)
#     try:
#         loop.run_forever()
#     finally:
#         loop.close()

def advertise():
    """Broadcasts the server IP.""" 
    sock = socket(AF_INET, SOCK_DGRAM, 0)
    sock.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
    sock.setsockopt(SOL_SOCKET, SO_BROADCAST, 1)
    sock.setblocking(False)
    sock.connect(('255.255.255.255', 3699))

    addr = str(sock.getsockname()[0]).encode()
    loop = asyncio.get_event_loop()
    theta = loop.time()

    def tick():
        """Advance the clock."""
        nonlocal theta
        sock.sendto(addr, ('255.255.255.255', 3699))
        theta += 1
        loop.call_at(theta, tick)

    tick()

def serve(agent):
    """Handles client connections."""
    sock = socket(AF_INET, SOCK_DGRAM, 0)
    sock.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
    sock.setblocking(False)
    sock.bind(('0.0.0.0', 3700))

    loop = asyncio.get_event_loop()
    theta = loop.time()
    clients = {}

    def tick():
        """Advances the clock."""
        nonlocal agent, clients, theta

        # drop stale clients
        now = loop.time()
        new_clients = {}
        for addr, then in clients.items():
            if now - then < 3:
                new_clients[addr] = then
            else:
                print('DISCONNECT ', addr)
        clients = new_clients

        # update fresh clients
        for addr in clients:
            msg = 'TICK {:.2f} {:.2f}'.format(agent.pos[0], agent.pos[1])
            sock.sendto(msg.encode(), addr)

        # handle incoming requests
        while True:
            results = select([sock], [], [sock], 0.001)
            if results[0] == []:
                break

            msg, addr = sock.recvfrom(1025)
            cmd = msg.decode('utf-8').split(' ')

            if cmd[0] == 'CONNECT':
                print('CONNECT {}:{}'.format(*addr))
                clients[addr] = loop.time()
            else:
                print('BAD COMMAND ', cmd)

        theta += 0.1
        loop.call_at(theta, tick)

    tick()

def main():
    """The main function."""
    agent = Agent(50, 50)

    loop = asyncio.get_event_loop()
    loop.call_soon(simulate, agent)
    loop.call_soon(advertise)
    loop.call_soon(serve, agent)
    try:
        loop.run_forever()
    finally:
        loop.close()

if __name__ == '__main__':
    main()
