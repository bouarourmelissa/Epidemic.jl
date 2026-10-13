using Epidemic

# ----------------------------------------------------
# 4. Aggregation & Data Collection
# ----------------------------------------------------
# Define metrics accepting exactly one argument: the model
susceptible_count(m) = count(a -> a.status == susceptible, allagents(m))
infected_count(m)    = count(a -> a.status == infected, allagents(m))
immune_count(m)      = count(a -> a.status == immune, allagents(m))

# Initialize model
model = Epidemic.initialize_model()

# Set simulation duration
n_steps = 300

# Collect data: passing model-level functions into mdata
mdata = [susceptible_count, infected_count, immune_count]

# Run simulation
df_agent, df_model.time = Epidemic.run!(model, n_steps; mdata = mdata)

# Print first few rows to verify the dataframe columns exist
println(names(df_model.time))
# Typically: ["step", "susceptible_count", "infected_count", "immune_count"]

# ----------------------------------------------------
# 5. Visualization with CairoMakie
# ----------------------------------------------------
fig = Figure(size = (850, 480))
ax = Axis(
    fig[1, 1], 
    xlabel = "Ticks", 
    ylabel = "Agent Count", 
    title = "Virus Simulation Dynamics (Masks & Vaccines Active)"
)

# Plot curves referencing the exact generated column names
lines!(ax, df_model.step, df_model.susceptible_count, label = "Susceptible", color = :royalblue, linewidth = 2.5)
lines!(ax, df_model.step, df_model.infected_count,    label = "Infected",    color = :crimson,   linewidth = 2.5)
lines!(ax, df_model.step, df_model.immune_count,      label = "Immune",      color = :seagreen,  linewidth = 2.5)

axislegend(ax, position = :rt)

save("virus_simulation_results.png", fig)
println("Simulation complete. Successfully saved to virus_simulation_results.png")