from bnd_lexer import bnd_lexer
from bnd_parser import bnd_parser
from cfg_lexer import cfg_lexer
from cfg_parser import cfg_parser

from cfg_types import *
from bnd_types import *

import sys


def get_internals(nodes, cfg):
    internals = []

    for decl in cfg:
        if type(decl) == AttrDeclaration:
            # TODO here we expect that is_internal expression is a constant
            if decl.attr == 'is_internal' and decl.expr.evaluate({}) == True:
                internals.append(decl.name)

    arr = []

    for i, node in enumerate(nodes):
        if node.name in internals:
            arr.append(str(i))

    return arr


def get_free_and_fixed_vars(nodes, cfg):
    initials = []

    for decl in cfg:
        if type(decl) == AttrDeclaration:
            # TODO here we expect that isstate expression is a constant
            if decl.attr == 'istate':
                initials.append((decl.name, decl.expr.evaluate({})))

    fixed_vars = set()

    fixed = []

    for state in initials:
        idx = [node.name for node in nodes].index(state[0])
        fixed_vars.add(idx)
        fixed.append(f'{{{idx}, {"true" if state[1] != 0 else "false"}}}')

    free_vars = set(range(len(nodes))).difference(fixed_vars)

    free = [str(x) for x in free_vars]

    return fixed, free


def get_constant(name, cfg):
    for decl in cfg:
        if type(decl) == ConstantDeclaration:
            if decl.name == name:
                return decl.expr.evaluate({})

    return None


def generate_header_file(nodes, cfg):
    internals = get_internals(nodes, cfg)
    fixed, free = get_free_and_fixed_vars(nodes, cfg)
    max_time = get_constant('max_time', cfg)
    time_tick = get_constant('time_tick', cfg)
    seed = get_constant('seed_pseudorandom', cfg)
    discrete_time = get_constant('discrete_time', cfg)
    sample_count = get_constant('sample_count', cfg)

    return f'''#pragma once
#include <utility>

constexpr int states_count = {len(nodes)};

constexpr int internals_count = {len(internals)};
constexpr int internals[{max(len(internals), 1)}] = {{ {', '.join(internals) if len(internals) != 0 else '0'} }};

constexpr int fixed_vars_count = {len(fixed)};
constexpr std::pair<int, bool> fixed_vars[{max(len(fixed), 1)}] = {{ {', '.join(fixed) if len(fixed) != 0 else '0'} }};

constexpr int free_vars_count = {len(free)};
constexpr int free_vars[{max(len(free), 1)}] = {{ {', '.join(free) if len(free) != 0 else '0'} }};

constexpr float max_time = (float){max_time if max_time is not None else 10};
constexpr float time_tick = (float){time_tick if time_tick is not None else 1};
constexpr unsigned long long seed = {seed if seed is not None else 0};
constexpr bool discrete_time = {'true' if discrete_time == 1 else 'false'};
constexpr int sample_count = {sample_count if sample_count is not None else 1000000};
'''


def generate_heading():
    return '''#include "types.h"
'''


def generate_aggregate_function(nodes):

    aggregate_function = '''
__device__ void compute_transition_rates(float* __restrict__ transition_rates, const state_t& state)
{'''

    for i, node in enumerate(nodes):
        aggregate_function += f'''
    transition_rates[{i}] = {node.name}_rate(state);'''

    aggregate_function += '''
}
'''

    return aggregate_function


def generate_node_transition_fuction(node, nodes, variables):

    node_name = node.name
    up_expr = node.attributes['rate_up'].generate_code(variables, nodes, node)
    down_expr = node.attributes['rate_down'].generate_code(
        variables, nodes, node)

    return f'''
__device__ float {node_name}_rate(const state_t& state)
{{
    return {Id(node_name).generate_code(variables, nodes, node)} ? 
        ({down_expr}) : 
        ({up_expr});
}}
'''


def generate_kernel(bnd_stream, cfg_stream, out_cu_file, out_h_file):

    bnd_program = bnd_parser.parse(bnd_stream, lexer=bnd_lexer)
    cfg_program = cfg_parser.parse(cfg_stream, lexer=cfg_lexer)

    if bnd_program is None or cfg_program is None:
        print('Error parsing input files')
        exit(1)

    # get list of nodes
    nodes = bnd_program

    # get dict of variables and their assignments
    variables = {}
    for declaration in cfg_program:
        if type(declaration) is VarDeclaration:
            variables[declaration.name] = declaration.evaluate(variables)

    f = open(out_cu_file, "w")

    f.write(generate_heading())

    # generate transition functions
    for node in nodes:
        f.write(generate_node_transition_fuction(node, nodes, variables))

    # generate aggregate function
    f.write(generate_aggregate_function(nodes))

    f.close()

    f = open(out_h_file, "w")

    # generate header
    f.write(generate_header_file(nodes, cfg_program))

    f.close()


if __name__ == '__main__':
    if len(sys.argv) != 5:
        print('Usage: python generator.py <bnd_file> <cfg_file> <out_cu_file> <out_h_file>')
        exit(1)

    bnd_file = sys.argv[1]
    cfg_file = sys.argv[2]
    out_cu_file = sys.argv[3]
    out_h_file = sys.argv[4]

    with open(bnd_file, 'r') as bnd:
        bnd_stream = bnd.read()
    with open(cfg_file, 'r') as cfg:
        cfg_stream = cfg.read()

    generate_kernel(bnd_stream, cfg_stream, out_cu_file, out_h_file)
