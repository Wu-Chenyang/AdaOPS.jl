using AdaOPS
using Test

using POMDPs
using POMDPModels
using POMDPSimulators
using Random
using POMDPModelTools
using ParticleFilters
using BeliefUpdaters
using StaticArrays
using POMDPPolicies
using Plots
ENV["GKSwstype"] = "100"
theme(:mute)

# include("baby_sanity_check.jl")
include("independent_bounds.jl")

pomdp = BabyPOMDP()
pomdp.discount = 1.0
p = solve(AdaOPSSolver(tree_in_info=true), pomdp)
Random.seed!(p, 1)

K = 10
b0 = initialstate(pomdp)
o = false
tval = 7.0
a, info = action_info(p, b0)
tree = info[:tree]
tree.obs[2] = o
b = WPFBelief([rand(b0)], [1.0], 2, 1, tree, o)

pol = FeedWhenCrying()
rng = MersenneTwister(2)

# AbstractParticleBelief interface
@testset "WPFBelief" begin
    @test n_particles(b) == 1
    s = particle(b,1)
    @test rand(rng, b) == s
    @test pdf(b, rand(rng, b)) == 1
    sup = support(b)
    @test length(sup) == 1
    @test first(sup) == s
    @test mode(b) == s
    @test mean(b) == s
    @test first(particles(b)) == s
    @test first(weights(b)) == 1.0
    @test first(weighted_particles(b)) == (s => 1.0)
    @test weight_sum(b) == 1.0
    @test weight(b, 1) == 1.0
    @test currentobs(b) == o
    @test history(b)[end].o == o
    @test initialize_belief(KMarkovUpdater(2), b)[end] == o
end

# Light Dark Test
pomdp = LightDark1D()
random = solve(RandomSolver(), pomdp)
Base.convert(::Type{SVector{1,Float64}}, s::LightDark1DState) = SVector{1,Float64}(s.y)
grid = StateGrid(range(-10, stop=15, length=26))
bds = IndependentBounds(FORollout(random), EntropyPenalizedEstimator(pomdp.correct_r, 0.03))
solver = AdaOPSSolver(bounds=bds,
                    grid=grid,
                    m_min=30,
                    delta=1.0,
                    tree_in_info=true
                    )
planner = solve(solver, pomdp)
action(planner, initialstate(pomdp))
hr = HistoryRecorder(max_steps=50)
@time hist = simulate(hr, pomdp, planner)
hist_analysis(hist)
println("Discounted reward is $(discounted_reward(hist))")

# BabyPOMDP Test
Base.convert(::Type{SVector{1,Float64}}, s::Bool) = SVector{1,Float64}(s)
# Type stability
pomdp = BabyPOMDP()
# bds = (pomdp, b)->(reward(pomdp, true, false)/(1-discount(pomdp)), 0.0)
bds = IndependentBounds(reward(pomdp, true, false)/(1-discount(pomdp)), EntropyPenalizedEstimator(0.0, 0.01))
solver = AdaOPSSolver(bounds=bds,
                      rng=MersenneTwister(4),
                      m_min=100,
                      tree_in_info=true
                     )
p = solve(solver, pomdp)

b0 = initialstate(pomdp)
D, Depth = @inferred AdaOPS.build_tree(p, b0)
@inferred action_info(p, b0)
a, info = action_info(p, b0)
info_analysis(info)
@inferred AdaOPS.explore!(D, 1, p)
Δu, Δl = @inferred AdaOPS.expand!(D, D.b, p)
@inferred AdaOPS.backup!(D, 1, p, Δu, Δl)
@inferred AdaOPS.next_best(D, 1, p)
@inferred AdaOPS.excess_uncertainty(D, 1, AdaOPS.solver(p).xi, p)
@inferred action(p, b0)

pomdp = BabyPOMDP()

# constant bounds
bds = IndependentBounds(reward(pomdp, true, false)/(1-discount(pomdp)), EntropyPenalizedEstimator(0.0, 0.01))
solver = AdaOPSSolver(bounds=bds, m_min=200, tree_in_info=true, num_b=10_000)
planner = solve(solver, pomdp)
hr = HistoryRecorder(max_steps=20)
@time hist = simulate(hr, pomdp, planner)
hist_analysis(hist)
println("Discounted reward is $(discounted_reward(hist))")

# SemiPORollout lower bound
bds = IndependentBounds(SemiPORollout(FeedWhenCrying()), EntropyPenalizedEstimator(0.0, 0.01))
solver = AdaOPSSolver(bounds=bds, m_min=200, tree_in_info=true, num_b=10_000)
planner = solve(solver, pomdp)
hr = HistoryRecorder(max_steps=20)
@time hist = simulate(hr, pomdp, planner)
hist_analysis(hist)
println("Discounted reward is $(discounted_reward(hist))")

# PO policy lower bound
bds = IndependentBounds(PORollout(FeedWhenCrying(), PreviousObservationUpdater()), EntropyPenalizedEstimator(0.0, 0.01))
solver = AdaOPSSolver(bounds=bds, m_min=200, tree_in_info=true, num_b=10_000)
planner = solve(solver, pomdp)
hr = HistoryRecorder(max_steps=20)
@time hist = simulate(hr, pomdp, planner)
hist_analysis(hist)
println("Discounted reward is $(discounted_reward(hist))")

# from README:
using POMDPs, POMDPModels, POMDPSimulators, AdaOPS

pomdp = TigerPOMDP()

solver = AdaOPSSolver(bounds=IndependentBounds(-20.0, 0.0))
planner = solve(solver, pomdp)

for (s, a, o) in stepthrough(pomdp, planner, "s,a,o", max_steps=10)
    println("State was $s,")
    println("action $a was taken,")
    println("and observation $o was received.\n")
end
