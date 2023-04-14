
__device__ float CycD_rate(size_t state)
{
    return (state & 1) ? 
        ((state & 1) ? 0.0 : 10) : 
        ((state & 1) ? 10 : 0.0);
}

__device__ float CycE_rate(size_t state)
{
    return (state & 2) ? 
        (!(state & 16) && (state & 32) ? 0.0 : 10) : 
        (!(state & 16) && (state & 32) ? 1 : 0.0);
}

__device__ float CycA_rate(size_t state)
{
    return (state & 4) ? 
        (!(state & 16) && !(state & 128) && !((state & 256) && (state & 512)) && ((state & 4) || (state & 32)) ? 0.0 : 10) : 
        (!(state & 16) && !(state & 128) && !((state & 256) && (state & 512)) && ((state & 4) || (state & 32)) ? 1 : 0.0);
}

__device__ float CycB_rate(size_t state)
{
    return (state & 8) ? 
        (!(state & 128) && !(state & 512) ? 0.0 : 10) : 
        (!(state & 128) && !(state & 512) ? 1 : 0.0);
}

__device__ float Rb_rate(size_t state)
{
    return (state & 16) ? 
        (!(state & 1) && !(state & 8) && ((state & 64) || !((state & 4) || (state & 2))) ? 0.0 : 10) : 
        (!(state & 1) && !(state & 8) && ((state & 64) || !((state & 4) || (state & 2))) ? 10 : 0.0);
}

__device__ float E2F_rate(size_t state)
{
    return (state & 32) ? 
        (!(state & 16) && !(state & 8) && (!(state & 4) || (state & 64)) ? 0.0 : 10) : 
        (!(state & 16) && !(state & 8) && (!(state & 4) || (state & 64)) ? 1 : 0.0);
}

__device__ float p27_rate(size_t state)
{
    return (state & 64) ? 
        (!(state & 1) && !(state & 8) && (!((state & 4) || (state & 2)) || ((state & 64) && !((state & 2) && (state & 4)))) ? 0.0 : 10) : 
        (!(state & 1) && !(state & 8) && (!((state & 4) || (state & 2)) || ((state & 64) && !((state & 2) && (state & 4)))) ? 10 : 0.0);
}

__device__ float Cdc20_rate(size_t state)
{
    return (state & 128) ? 
        ((state & 8) ? 0.0 : 10) : 
        ((state & 8) ? 1 : 0.0);
}

__device__ float UbcH10_rate(size_t state)
{
    return (state & 256) ? 
        ((!((state & 512) && !(state & 256)) && ((state & 4) || (state & 8))) || (!(state & 4) && !(state & 8) && (!(state & 512) || ((state & 128) && (state & 256)))) ? 0.0 : 10) : 
        ((!((state & 512) && !(state & 256)) && ((state & 4) || (state & 8))) || (!(state & 4) && !(state & 8) && (!(state & 512) || ((state & 128) && (state & 256)))) ? 1 : 0.0);
}

__device__ float cdh1_rate(size_t state)
{
    return (state & 512) ? 
        ((state & 128) || (!(state & 8) && (!(state & 4) || (state & 64))) ? 0.0 : 10) : 
        ((state & 128) || (!(state & 8) && (!(state & 4) || (state & 64))) ? 10 : 0.0);
}

__device__ void compute_transition_rates(float* __restrict__ transition_rates, size_t state)
{
    transition_rates[0] = CycD_rate(state);
    transition_rates[1] = CycE_rate(state);
    transition_rates[2] = CycA_rate(state);
    transition_rates[3] = CycB_rate(state);
    transition_rates[4] = Rb_rate(state);
    transition_rates[5] = E2F_rate(state);
    transition_rates[6] = p27_rate(state);
    transition_rates[7] = Cdc20_rate(state);
    transition_rates[8] = UbcH10_rate(state);
    transition_rates[9] = cdh1_rate(state);
}