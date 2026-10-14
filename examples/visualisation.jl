# =====================================================================
# examples/visualisations.jl
# Visualisations de la population et de la propagation de l'épidémie
#
# Lancer depuis la racine du projet :
#   julia --project=. examples/visualisations.jl
# Les images / vidéos sont sauvegardées dans examples/figures/
# =====================================================================
using Epidemic
using Agents: run!, step!, allagents, nagents
using CairoMakie

const DOSSIER = joinpath(@__DIR__, "figures")
mkpath(DOSSIER)

# ---------------------------------------------------------------------
# 0. Couleurs et fonctions utilitaires
# ---------------------------------------------------------------------
const COULEURS = Dict(
    susceptible => :royalblue,
    exposed     => :orange,
    infected    => :crimson,
    recovered   => :seagreen,
)
const NOMS = ["Susceptible", "Exposed", "Infected", "Recovered"]
const ORDRE = [susceptible, exposed, infected, recovered]

# Métriques collectées à chaque pas (un seul argument : le modèle)
compte(m, s) = count(a -> a.status == s, allagents(m))
n_S(m)     = compte(m, susceptible)
n_E(m)     = compte(m, exposed)
n_I(m)     = compte(m, infected)
n_R(m)     = compte(m, recovered)
n_total(m) = nagents(m)

# Position d'un agent avec un petit décalage (pour ne pas empiler
# les agents qui sont sur la même case de la grille)
position_agent(a) = Point2f(
    a.pos[1] + 0.35 * sin(a.id * 12.9898),
    a.pos[2] + 0.35 * cos(a.id * 78.233),
)
couleur_agent(a) = to_color(COULEURS[a.status])

# Lance une simulation et renvoie le DataFrame des résultats
function lancer(; n_steps = 300, kwargs...)
    model = initialize_model(; kwargs...)
    _, df = run!(model, n_steps; mdata = [n_S, n_E, n_I, n_R, n_total])
    return df
end

# ---------------------------------------------------------------------
# 1. Évolution de la population : effectifs + proportions
# ---------------------------------------------------------------------
function figure_population(df)
    t   = df.time
    tot = max.(df.n_total, 1)           # évite la division par 0

    fig = Figure(size = (1000, 800))

    # (a) Effectifs de chaque compartiment + population totale
    ax1 = Axis(fig[1, 1]; xlabel = "Step", ylabel = "Nombre d'agents",
               title = "Effectifs par état de santé")
    lines!(ax1, t, df.n_S; color = :royalblue, linewidth = 2.5, label = "Susceptible")
    lines!(ax1, t, df.n_E; color = :orange,    linewidth = 2.5, label = "Exposed")
    lines!(ax1, t, df.n_I; color = :crimson,   linewidth = 2.5, label = "Infected")
    lines!(ax1, t, df.n_R; color = :seagreen,  linewidth = 2.5, label = "Recovered")
    lines!(ax1, t, df.n_total; color = :black, linewidth = 2,
           linestyle = :dash, label = "Population totale")
    axislegend(ax1; position = :rt)

    # (b) Proportions de la population (aires empilées = 100 %)
    ax2 = Axis(fig[2, 1]; xlabel = "Step", ylabel = "Part de la population",
               title = "Répartition de la population (%)",
               limits = (nothing, nothing, 0, 1))
    s  = df.n_S ./ tot
    e  = s .+ df.n_E ./ tot
    i  = e .+ df.n_I ./ tot
    r  = i .+ df.n_R ./ tot
    z  = zeros(length(t))
    band!(ax2, t, z, s; color = :royalblue)
    band!(ax2, t, s, e; color = :orange)
    band!(ax2, t, e, i; color = :crimson)
    band!(ax2, t, i, r; color = :seagreen)

    return fig
end

# ---------------------------------------------------------------------
# 2. Propagation dans l'espace : instantanés de la grille
# ---------------------------------------------------------------------
function figure_spatiale(; steps = [0, 25, 50, 100, 200, 300],
                           dims = (35, 35), kwargs...)
    model   = initialize_model(; dims, kwargs...)
    fig     = Figure(size = (1100, 800))
    courant = 0

    for (k, t) in enumerate(steps)
        t > courant && step!(model, t - courant)
        courant = t

        ax = Axis(fig[div(k - 1, 3) + 1, mod(k - 1, 3) + 1];
                  title = "t = $t  (N = $(nagents(model)))",
                  aspect = DataAspect(),
                  limits = (0, dims[1] + 1, 0, dims[2] + 1))
        hidedecorations!(ax)

        ags = collect(allagents(model))
        scatter!(ax, position_agent.(ags);
                 color = couleur_agent.(ags), markersize = 9)
    end

    # Légende commune
    Legend(fig[3, 1:3],
           [MarkerElement(color = COULEURS[s], marker = :circle, markersize = 12)
            for s in ORDRE],
           NOMS; orientation = :horizontal, framevisible = false)

    return fig
end

# ---------------------------------------------------------------------
# 3. Animation de la propagation
# ---------------------------------------------------------------------
function animation_propagation(; n_steps = 200, dims = (35, 35),
                                 fichier = joinpath(DOSSIER, "propagation.mp4"),
                                 kwargs...)
    model = initialize_model(; dims, kwargs...)

    ags   = Observable(collect(allagents(model)))
    pos   = lift(a -> position_agent.(a), ags)
    col   = lift(a -> couleur_agent.(a), ags)
    titre = Observable("t = 0")

    fig = Figure(size = (700, 740))
    ax  = Axis(fig[1, 1]; title = titre, aspect = DataAspect(),
               limits = (0, dims[1] + 1, 0, dims[2] + 1))
    hidedecorations!(ax)
    scatter!(ax, pos; color = col, markersize = 9)

    record(fig, fichier, 0:n_steps; framerate = 15) do t
        t > 0 && step!(model, 1)
        titre[] = "t = $t   |   N = $(nagents(model))"
        ags[]   = collect(allagents(model))
    end
    return fichier
end

# ---------------------------------------------------------------------
# 4. Effet des masques et du vaccin (comparaison de scénarios)
# ---------------------------------------------------------------------
function figure_scenarios(; n_steps = 300, seed = 42)
    scenarios = [
        ("Aucune protection", (mask_probability = 0.0, vaccination_probability = 0.0), :black),
        ("Masques seulement", (mask_probability = 0.5, vaccination_probability = 0.0), :orange),
        ("Vaccin seulement",  (mask_probability = 0.0, vaccination_probability = 0.6), :royalblue),
        ("Masques + vaccin",  (mask_probability = 0.5, vaccination_probability = 0.6), :seagreen),
    ]

    fig = Figure(size = (900, 500))
    ax  = Axis(fig[1, 1]; xlabel = "Step",
               ylabel = "Infectés / population (%)",
               title  = "Effet des masques et du vaccin sur l'épidémie")

    for (nom, params, couleur) in scenarios
        df = lancer(; n_steps, seed, params...)
        lines!(ax, df.time, 100 .* df.n_I ./ max.(df.n_total, 1);
               label = nom, color = couleur, linewidth = 2.5)
    end
    axislegend(ax; position = :rt)
    return fig
end

# ---------------------------------------------------------------------
# Exécution
# ---------------------------------------------------------------------
df = lancer(n_steps = 300)

save(joinpath(DOSSIER, "population.png"), figure_population(df))
save(joinpath(DOSSIER, "propagation_spatiale.png"), figure_spatiale())
save(joinpath(DOSSIER, "scenarios.png"), figure_scenarios())
animation_propagation()          # décommente/commente selon ton besoin

println("Terminé — résultats dans : ", DOSSIER)