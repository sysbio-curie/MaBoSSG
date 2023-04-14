#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#include "simulation.h"
#include "transition_rates.cuh"

#include "generated.cu.g"

template <size_t states_count>
__device__ int select_flip_bit(const float* __restrict__ transition_rates, size_t state, float total_rate,
							   curandState* __restrict__ rand)
{
	float r = curand_uniform(rand) * total_rate;
	float sum = 0;
	for (int i = 0; i < states_count; i++)
	{
		sum += transition_rates[i];
		if (r < sum)
			return i;
	}
	return states_count - 1;
}

template <size_t states_count>
__global__ void initialize(int trajectories_count, unsigned long long seed, size_t* __restrict__ states,
						   float* __restrict__ times, curandState* __restrict__ rands)
{
	auto id = blockIdx.x * blockDim.x + threadIdx.x;
	if (id >= trajectories_count)
		return;

	// initialize random number generator
	curand_init(seed, id, 0, rands + id);

	// randomize initial states TODO mask out fixed bits
	float r = curand_uniform(rands + id);
	states[id] = (size_t)(((1 << states_count) - 1) * r);

	// set time to zero
	times[id] = 0.f;
}

void run_initialize(int trajectories_count, unsigned long long seed, size_t* states, float* times, curandState* rands)
{
	initialize<10><<<trajectories_count / 256 + 1, 256>>>(trajectories_count, seed, states, times, rands);
}

template <size_t states_count>
__global__ void simulate(float max_time, int trajectories_count, size_t* __restrict__ states, float* __restrict__ times,
						 curandState* __restrict__ rands, size_t* __restrict__ trajectory_states,
						 float* __restrict__ trajectory_times, const size_t trajectory_limit,
						 size_t* __restrict__ used_trajectory_size, bool* __restrict__ finished)
{
	auto id = blockIdx.x * blockDim.x + threadIdx.x;
	if (id >= trajectories_count)
		return;

	float transition_rates[states_count];

	// Initialize thread variables
	curandState rand = rands[id];
	size_t state = states[id];
	float time = times[id];
	size_t step = 0;
	trajectory_states = trajectory_states + id * trajectory_limit;
	trajectory_times = trajectory_times + id * trajectory_limit;

	while (true)
	{
		// get transition rates for current state
		compute_transition_rates(transition_rates, state);

		// sum up transition rates
		float total_rate = 0;
		for (size_t i = 0; i < states_count; i++)
			total_rate += transition_rates[i];

		// if total rate is zero, no transition is possible
		if (total_rate == 0.f)
			time = max_time;
		else
			time += -logf(curand_uniform(&rand)) / total_rate;

		trajectory_states[step] = state;
		trajectory_times[step] = time;
		step++;

		if (time >= max_time || step >= trajectory_limit)
			break;

		int flip_bit = select_flip_bit<states_count>(transition_rates, state, total_rate, &rand);
		state ^= 1 << flip_bit;
	}

	// save thread variables
	rands[id] = rand;
	states[id] = state;
	times[id] = time;
	used_trajectory_size[id] = step;

    if (step == trajectory_limit)
        *finished = false;
}

void run_simulate(float max_time, int trajectories_count, size_t* states, float* times, curandState* rands,
				  size_t* trajectory_states, float* trajectory_times, const size_t trajectory_limit,
				  size_t* used_trajectory_size, bool* finished)
{
	simulate<10><<<trajectories_count / 256 + 1, 256>>>(max_time, trajectories_count, states, times, rands,
														trajectory_states, trajectory_times, trajectory_limit,
														used_trajectory_size, finished);
}