#include <thrust/copy.h>
#include <thrust/count.h>
#include <thrust/device_vector.h>
#include <thrust/iterator/constant_iterator.h>
#include <thrust/reduce.h>
#include <thrust/sort.h>
#include <thrust/unique.h>

#include "statistics.h"
#include "timer.h"

constexpr bool print_diags = false;

void fixed_points(fp_map_t& fixed_points_occurences, size_t& total_occurences, thrust::device_ptr<state_t> last_states,
				  thrust::device_ptr<int> traj_lengths, int max_traj_len, int n_trajectories)
{
	timer t;
	float copy_sort_reduce_time = 0.f, update_time = 0.f;

	t.start();

	auto fp_pred = [max_traj_len, traj_lengths] __device__(int len) { return len < max_traj_len; };

	size_t finished_trajs_size = thrust::count_if(traj_lengths, traj_lengths + n_trajectories, fp_pred);

	if (finished_trajs_size == 0)
		return;

	thrust::device_vector<state_t> final_states(finished_trajs_size);

	thrust::copy_if(last_states, last_states + n_trajectories, traj_lengths, final_states.begin(), fp_pred);

	thrust::sort(final_states.begin(), final_states.end());

	size_t unique_fixed_points_size = thrust::unique_count(final_states.begin(), final_states.end());

	thrust::device_vector<state_t> unique_fixed_points(unique_fixed_points_size);
	thrust::device_vector<int> unique_fixed_points_count(unique_fixed_points_size);

	thrust::reduce_by_key(final_states.begin(), final_states.end(), thrust::make_constant_iterator(1),
						  unique_fixed_points.begin(), unique_fixed_points_count.begin());

	t.stop();
	copy_sort_reduce_time = t.millisecs();
	t.start();

	std::vector<state_t> h_unique_fixed_points(unique_fixed_points_size);
	std::vector<int> h_unique_fixed_points_count(unique_fixed_points_size);

	thrust::copy(unique_fixed_points.begin(), unique_fixed_points.end(), h_unique_fixed_points.begin());
	thrust::copy(unique_fixed_points_count.begin(), unique_fixed_points_count.end(),
				 h_unique_fixed_points_count.begin());

	for (size_t i = 0; i < unique_fixed_points_size; i++)
	{
		auto it = fixed_points_occurences.find(h_unique_fixed_points[i]);

		if (it != fixed_points_occurences.end())
			fixed_points_occurences[h_unique_fixed_points[i]] += h_unique_fixed_points_count[i];
		else
			fixed_points_occurences[h_unique_fixed_points[i]] = h_unique_fixed_points_count[i];

		total_occurences += h_unique_fixed_points_count[i];
	}

	t.stop();

	update_time = t.millisecs();

	if (print_diags)
	{
		std::cout << "fixed_points> copy_sort_reduce_time: " << copy_sort_reduce_time << "ms" << std::endl;
		std::cout << "fixed_points> update_time: " << update_time << "ms" << std::endl;
		std::cout << "fixed_points> total occurences: " << total_occurences << std::endl;
	}
}