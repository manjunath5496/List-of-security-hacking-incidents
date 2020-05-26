
## data

import scipy.io
mat = scipy.io.loadmat('p4_data.mat')
matrix = mat['data'][0][0][1]

## create graph in networkx

from networkx import Graph
import sys
import re
import itertools
import time

g = Graph()

n, m = matrix.shape

for i in range(n):
	for j in range(m):
		if matrix[i][j] != 0:
			g.add_edge(i,j)

## basic check 

assert(g.number_of_edges())*2 == len(matrix.nonzero()[0])

## cluster coefficient: count triplets and triangles

def wedge_iterator(graph):
	nodes_iter = graph.nodes()
	for node in nodes_iter:
		neighbors = graph.neighbors(node)
		for pair in itertools.combinations(neighbors, 2):
			yield (node, pair)


def count_triplets(graph):
	return len(list(wedge_iterator(graph)))


def count_triangle(graph):
	n = 0
	for wedge in wedge_iterator(graph):
		if graph.has_edge(wedge[1][0], wedge[1][1]) or graph.has_edge(wedge[1][1], wedge[1][0]):
			n += 1
	n = n/3 # remove triple counting
	return n

triplets = count_triplets(g)
triangles = count_triangle(g)

cluster_coeff = 3.0 * triangles / triplets

## degree distribution

from collections import Counter

# compute distribution 

degrees = map(lambda x:x[1], g.degree())
total = float(len(degrees))
dist = map(lambda (k,v): (k, float(v) / total), Counter(degrees).items())
dist = sorted(dist, key = lambda x:x[0])

# plot

import matplotlib.pyplot as plt
x, y = zip(*dist)
plt.plot(x,y)
plt.show() # bar plot may look better

## average (shorted) path length

from networkx import average_shortest_path_length as f

avg_path_length = f(g)

## diameter

from networkx import diameter

dia = diameter(g)


