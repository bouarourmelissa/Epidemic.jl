using Epidemic
<<<<<<< HEAD

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
=======
using Agents: run!, allagents
using CairoMakie

# ----------------------------------------------------
# 1. Aggregation & Data Collection
# ----------------------------------------------------
# Each metric takes exactly one argument: the model
susceptible_count(m) = count(a -> a.status == susceptible, allagents(m))
exposed_count(m)     = count(a -> a.status == exposed,     allagents(m))
infected_count(m)    = count(a -> a.status == infected,    allagents(m))
recovered_count(m)   = count(a -> a.status == recovered,   allagents(m))

# ----------------------------------------------------
# 2. Run the Simulation
# ----------------------------------------------------
model = initialize_model()

n_steps = 300

mdata = [susceptible_count, exposed_count, infected_count, recovered_count]

_, df_model = run!(model, n_steps; mdata)

println("Columns: ", names(df_model))
println(first(df_model, 5))

# ----------------------------------------------------
# 3. Visualization with CairoMakie
# ----------------------------------------------------
fig = Figure(size = (900, 500))
ax  = Axis(
    fig[1, 1];
    xlabel = "Step",
    ylabel = "Agent Count",
    title  = "SEIRS Epidemic Simulation (Masks & Vaccines Active)",
)

lines!(ax, df_model.time, df_model.susceptible_count;
       label = "Susceptible", color = :royalblue, linewidth = 2.5)
lines!(ax, df_model.time, df_model.exposed_count;
       label = "Exposed",     color = :orange,    linewidth = 2.5)
lines!(ax, df_model.time, df_model.infected_count;
       label = "Infected",    color = :crimson,   linewidth = 2.5)
lines!(ax, df_model.time, df_model.recovered_count;
       label = "Recovered",   color = :seagreen,  linewidth = 2.5)

axislegend(ax; position = :rt)

save("seirs_simulation.png", fig)
println("Simulation complete — saved to seirs_simulation.png")
>>>>>>> 3985c7dd32de6d2a6d128fec98a8b0b5bf9c38dd
