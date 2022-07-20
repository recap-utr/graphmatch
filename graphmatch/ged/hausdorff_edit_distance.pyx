# coding = utf-8

import numpy as np
cimport numpy as np
from ..base cimport Base
from cython.parallel cimport prange,parallel
from ..helpers.general import parsenx2graph
cimport cython

cdef class HED(Base):
    """
    Implementation of Hausdorff Edit Distance described in

    Improved quadratic time approximation of graph edit distance by Hausdorff matching and greedy assignement
    Andreas Fischer, Kaspar Riesen, Horst Bunke
    2016
    """

    cdef int node_del
    cdef int node_ins
    cdef int edge_del
    cdef int edge_ins

    def __init__(self, int node_del=1, int node_ins=1, int edge_del=1, int edge_ins=1):
        """
        HED Constructor

        Parameters
        ----------
        node_del :int
            Node deletion cost
        node_ins : int
            Node insertion cost
        edge_del : int
            Edge Deletion cost
        edge_ins : int
            Edge Insertion cost
        """
        Base.__init__(self,1,False)
        self.node_del = node_del
        self.node_ins = node_ins
        self.edge_del = edge_del
        self.edge_ins = edge_ins


    @cython.boundscheck(False)
    cpdef np.ndarray compare(self,list listgs, list selected):
        cdef int n = len(listgs)
        cdef list new_gs=parsenx2graph(listgs,self.node_attr_key,self.edge_attr_key)
        cdef double[:,:] comparison_matrix = np.zeros((n, n))
        cdef double[:] selected_test = np.array(self.get_selected_array(selected,n))
        cdef int i,j
        cdef long[:] n_nodes = np.array([g.size() for g in new_gs])
        cdef long[:] n_edges = np.array([g.density() for g in new_gs])

        with nogil, parallel(num_threads=self.cpu_count):
            for i in prange(n,schedule='static'):
                for j in range(i,n):
                    if  n_nodes[i] > 0 and n_nodes[j] > 0  and selected_test[i] == True:
                        with gil:
                            comparison_matrix[i, j] = self.hed(new_gs[i], new_gs[j])
                    else:
                        comparison_matrix[i, j] = 0
                    comparison_matrix[j, i] = comparison_matrix[i, j]

        return np.array(comparison_matrix)


    cdef float hed(self, g1, g2):
        """
        Compute the HED similarity value between two `graphmatch.Graph`

        Parameters
        ----------
        g1 : graphmatch.Graph
            First Graph
        g2 : graphmatch.Graph
            Second Graph

        Returns
        -------
        float
            similarity value
        """
        return self.sum_fuv(g1, g2) + self.sum_fuv(g2, g1)

    cdef float sum_fuv(self, g1, g2):
        """
        Compute Nearest Neighbour Distance between G1 and G2
        Parameters
        ----------
        g1 : graphmatch.Graph
            First graph
        g2 : graphmatch.Graph
            Second graph

        Returns
        -------
        float
            Nearest Neighbour Distance
        """

        cdef np.ndarray min_sum = np.zeros(g1.size())
        cdef list nodes1 = list(g1.nodes())
        cdef list nodes2 = list(g2.nodes())
        nodes2.extend([None])
        cdef np.ndarray min_i
        for i in range(g1.size()):
            min_i = np.zeros(g2.size())
            for j in range(g2.size()):
                min_i[j] = self.fuv(g1, g2, nodes1[i], nodes2[j])
            min_sum[i] = np.min(min_i)
        return np.sum(min_sum)

    cdef float fuv(self, g1, g2, str n1, str n2):
        """
        Compute the Node Distance function
        Parameters
        ----------
        g1 : graphmatch.Graph
            First graph
        g2 : graphmatch.Graph
            Second graph
        n1 : int or str
            identifier of the first node
        n2 : int or str
            identifier of the second node

        Returns
        -------
        float
            node distance
        """
        if n2 == None:  # Del
            return self.node_del + ((self.edge_del / 2.) * g1.degree(n1))
        if n1 == None:  # Insert
            return self.node_ins + ((self.edge_ins / 2.) * g2.degree(n2))
        else:
            if n1 == n2:
                return 0
            return (self.node_del + self.node_ins + self.hed_edge(g1, g2, n1, n2)) / 2

    cdef float hed_edge(self, g1, g2, str n1, str n2):
        """
        Compute HEDistance between edges of n1 and n2, respectively in g1 and g2
        Parameters
        ----------
        g1 : graphmatch.Graph
            First graph
        g2 : graphmatch.Graph
            Second graph
        n1 : int or str
            identifier of the first node
        n2 : int or str
            identifier of the second node

        Returns
        -------
        float
            HEDistance between g1 and g2
        """
        return self.sum_gpq(g1, n1, g2, n2) + self.sum_gpq(g1, n1, g2, n2)


    cdef float sum_gpq(self, g1, str n1, g2, str n2):
        """
        Compute Nearest Neighbour Distance between edges around n1 in G1  and edges around n2 in G2
        Parameters
        ----------
        g1 : graphmatch.Graph
            First graph
        g2 : graphmatch.Graph
            Second graph
        n1 : int or str
            identifier of the first node
        n2 : int or str
            identifier of the second node

        Returns
        -------
        float
            Nearest Neighbour Distance
        """

        #if isinstance(g1, nx.MultiDiGraph):
        cdef list edges1 = g1.get_edges_no(n1) if n1 else [] # rename method ...
        cdef list edges2 = g2.get_edges_no(n2) if n2 else []

        cdef np.ndarray min_sum = np.zeros(len(edges1))
        edges2.extend([None])
        cdef np.ndarray min_i
        for i in range(len(edges1)):
            min_i = np.zeros(len(edges2))
            for j in range(len(edges2)):
                min_i[j] = self.gpq(edges1[i], edges2[j])
            min_sum[i] = np.min(min_i)
        return np.sum(min_sum)

    cdef float gpq(self, str e1, str e2):
        """
        Compute the edge distance function
        Parameters
        ----------
        e1 : str
            first edge identifier
        e2
            second edge indentifier
        Returns
        -------
        float
            edge distance
        """
        if e2 == None:  # Del
            return self.edge_del
        if e1 == None:  # Insert
            return self.edge_ins
        else:
            if e1 == e2:
                return 0
            return (self.edge_del + self.edge_ins) / 2.
