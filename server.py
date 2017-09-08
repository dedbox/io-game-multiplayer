#!/usr/bin/env python

'''Physical simulation of dynamic agents.'''

from abc import abstractmethod
from numpy import array
from numpy.linalg import norm
from asyncio import get_event_loop
from select import select
from socket import AF_INET, SOCK_DGRAM, SOL_SOCKET, SO_REUSEADDR, SO_BROADCAST
from socket import socket

PULSE_PERIOD = 0.5
EPSILON = 0.01


class Simulator:
    '''Maintains consistent passage of time.'''

    def __init__(self, freq):
        self.period = 1 / freq
        self.now = None
        self.handle = None

    @abstractmethod
    def on_tick(self, delta):
        '''NOT IMPLEMENTED'''

    def tick(self):
        '''Advances the simulator by one tick.'''
        self.on_tick(self.period)
        self.now += self.period
        self.handle = get_event_loop().call_at(self.now, self.tick)

    def start(self):
        '''Runs the simulator.'''
        self.now = get_event_loop().time()
        self.tick()

    def stop(self):
        '''Halts the simulator.'''
        if self.handle:
            self.handle.cancel()
            self.handle = None


class Beacon(Simulator):
    '''Broadcasts the server IP.'''

    def __init__(self):
        super().__init__(1)
        self.sock = socket(AF_INET, SOCK_DGRAM, 0)
        self.sock.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
        self.sock.setsockopt(SOL_SOCKET, SO_BROADCAST, 1)
        self.sock.setblocking(False)
        self.sock.connect(('255.255.255.255', 3699))
        self.my_addr = str(self.sock.getsockname()[0]).encode()

    def on_tick(self, delta):
        print('BEACON', delta)
        self.sock.sendto(self.my_addr, ('255.255.255.255', 3699))


class Server(Simulator):
    '''Connects UDP clients to the world.'''

    def __init__(self):
        super().__init__(10)
        self.world = World()
        self.clients = {}
        self.sock = socket(AF_INET, SOCK_DGRAM, 0)
        self.sock.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1)
        self.sock.setblocking(False)
        self.sock.bind(('0.0.0.0', 3700))
        self.loop = get_event_loop()

    def on_tick(self, delta):
        self.drop_stale_clients()
        self.world.on_tick(delta)
        self.update_clients()
        self.handle_requests()

    def drop_stale_clients(self):
        now = self.loop.time()
        clients = {}
        for addr, then in self.clients.items():
            if now - then < 5 * PULSE_PERIOD:
                clients[addr] = then
            else:
                print(self.now, 'DISCONNECT', addr)
                self.world.stop_agent(addr)
        self.clients = clients

    def update_clients(self):
        for addr in self.clients:
            agent = self.world.agent(addr)
            if not agent:
                agent = self.world.start_agent(addr)

            self_msg = 'TICK|' + str(agent)
            self.sock.sendto(self_msg.encode(), addr)

            others_msg = ['OTHERS']
            for agent_addr, agent in self.world.agents.items():
                if agent_addr != addr:
                    others_msg += [str(agent_addr), str(agent)]
            if len(others_msg) > 0:
                self.sock.sendto('|'.join(others_msg).encode(), addr)

    def handle_requests(self):
        while True:
            rd = select([self.sock], [], [self.sock], 0.0001)
            if rd[0] == []:
                break

            msg, addr = self.sock.recvfrom(1024)
            cmd = msg.decode('utf-8').split('|')

            if cmd[0] == 'CONNECT':
                if addr in self.clients:
                    print(self.now, 'PING {}:{}'.format(*addr))
                else:
                    print(self.now, 'CONNECT {}:{}'.format(*addr))
                self.clients[addr] = self.loop.time()
            elif cmd[0] == 'MOVE':
                agent = self.world.agent(addr)
                if agent:
                    agent.move_to(cmd[1], cmd[2])
            else:
                print(self.now, 'BAD REQUEST', cmd)


class World(Simulator):
    '''A set of agents and the rules that govern their behavior.'''

    def __init__(self):
        super().__init__(10)
        self.agents = {}

    def start_agent(self, key):
        self.agents[key] = Agent()
        return self.agents[key]

    def agent(self, key):
        return self.agents.get(key)

    def stop_agent(self, key):
        self.agents[key].stop()
        del self.agents[key]

    def on_tick(self, delta):
        for key, agent in self.agents.items():
            if agent.is_alive() and not agent.is_idle():
                agent.tick(delta)
            if agent.is_alive() and not agent.is_idle():
                print('AGENT', key, agent.position)


class Agent:
    '''A physical object; An agent of visible change.'''

    def __init__(self, x=0, y=0):
        self.position = array([float(x), float(y)])
        self.speed = 20
        self.mode = 'IDLE'
        self.target = None

    def __str__(self):
        return '{:.2f}|{:.2f}'.format(*self.position)

    def is_alive(self):
        '''An agent is alive until it is dead.'''
        return self.mode != 'DEAD'

    def is_idle(self):
        '''An idle agent does nothing.'''
        return self.mode == 'IDLE'

    def tick(self, delta):
        '''Advance the agent simulation by one clock period.'''
        if self.mode == 'MOVE':
            trajectory = self.target - self.position
            distance = norm(trajectory)
            if distance == 0:
                heading = array([0.0, 0.0])
            else:
                heading = trajectory / distance
            step = heading * self.speed * delta
            self.position += step if norm(step) < distance else trajectory
            if distance < EPSILON:
                self.idle()

    def idle(self):
        '''Stop moving.'''
        print('IDLE')
        self.mode = 'IDLE'
        self.target = None

    def move_to(self, x, y):
        '''Start moving to the given coordinates.'''
        print('MOVE {} {}'.format(x, y))
        self.mode = 'MOVE'
        self.target = array([float(x), float(y)])

    def stop(self):
        '''Destroy the agent.'''
        print('DEAD')
        self.mode = 'DEAD'
        self.target = None


def main():
    server = Server()
    beacon = Beacon()

    loop = get_event_loop()
    loop.call_soon(server.start)
    loop.call_soon(beacon.start)
    loop.run_forever()


if __name__ == '__main__':
    main()
