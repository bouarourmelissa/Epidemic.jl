#  Constuire l'interface Epedimic Lab  : 

const DOM = Bonito.DOM
const EMOJIS = ["🙂", "😷", "🤒", "💪"]
const COL = ["#38bdf8", "#fb923c", "#f43f5e", "#4ade80"]

const CSS = read(joinpath(@__DIR__, "style.css"), String)




# Curseur avec son nom et sa valeur affichée
function curseur(nom, plage, valeur)
    s = Bonito.Slider(plage; value=valeur)
    txt = map(v -> v isa Integer ? string(v) : string(round(Float64(v); digits=2)), s.value)
    return s, DOM.div(nom, DOM.span(txt; class="val"), s; class="ligne")
end

# Une carte de chiffre
carte(emoji, nom, valeur, couleur; classe="stat") = DOM.div(
    DOM.div(emoji),
    DOM.div(string(valeur); class="chiffre",
        style="color:$couleur; text-shadow:0 0 14px $couleur"),
    DOM.div(nom; class="nom");
    class=classe, style="border-top-color:$couleur",
)

# Une rangée de 4 cartes qui se met à jour toute seule
rangee(obs, emojis, noms, couleurs; classe="stat") = map(obs) do v
    DOM.div([carte(emojis[i], noms[i], v[i], couleurs[i]; classe) for i in 1:4]...; class="stats")
end

# Une barre remplie à `pct` %
barre(pct, couleur; style="") = DOM.div(
    DOM.div(; class="rempli", style="width:$(round(pct; digits=1))%; background:$couleur");
    class="piste", style=style,
)

# ---------- Application ----------
function creer_app()
    return Bonito.App() do
        # Curseurs
        s_agents, l_agents = curseur("Population", 10:300, 150)
        s_inf, l_inf = curseur("Infectés initiaux", 0:50, 10)
        s_contag, l_contag = curseur("Contagiosité", 0.0:0.01:1.0, 0.65)
        s_lat, l_lat = curseur("Latence", 1:30, 8)
        s_duree, l_duree = curseur("Durée infection", 1:60, 25)
        s_gue, l_gue = curseur("Guérison", 0.0:0.01:1.0, 0.6)
        s_imm, l_imm = curseur("Immunité", 1:150, 40)
        s_mask, l_mask = curseur("Masques", 0.0:0.01:1.0, 0.5)
        s_vac, l_vac = curseur("Vaccination", 0.0:0.01:1.0, 0.6)
        s_vit, l_vit = curseur("Vitesse", 1:10, 5)
        s_jours, l_jours = curseur("Durée (jours)", 20:200, 50)

        strategy = Bonito.Dropdown(["Classique", "Protégée"]; index=1)
        b_lancer = Bonito.Button("▶ LANCER")
        b_pause = Bonito.Button("⏯ PAUSE")

        # Simulation
        sim = creer_simulation((; s_agents, s_inf, s_contag, s_lat, s_duree, s_gue,
            s_imm, s_mask, s_vac, s_vit, s_jours, strategy))

        on(b_lancer.value) do clicked
            clicked && @async sim.lancer() # demarrer la simulation aprés le clic
        end
        on(b_pause.value) do clicked
            (clicked && sim.en_cours[]) || return  # si clic et simulation en cours sinon return
            sim.pause[] = !sim.pause[]
            sim.statut[] = sim.pause[] ? "En pause" : "Reprise..."
        end

        # Blocs qui se mettent à jour tout seuls
        etats = rangee(sim.compte, EMOJIS, NOMS,COL)
        indicateurs = rangee(sim.indic, ["📈", "📅", "💀", "🛡️"],
            ["Pic d'infection", "Jour du pic", "Décès", "Immunisés"],
            [COL[3], "#c4a7ff", "#cbd5e1", COL[4]]; classe="stat petit")

        progression = map(sim.progression, sim.alerte_prog) do p, alerte
            couleur = alerte ? "linear-gradient(90deg,#f43f5e,#fb923c)" :
                               "linear-gradient(90deg,#7c5cff,#38bdf8)"
            barre(p, couleur; style="margin-bottom:18px")
        end

        journal = map(sim.lignes) do l
            isempty(l) ? DOM.p("Lancez la simulation pour suivre les événements."; class="nom") :
                         DOM.div([DOM.p(x; class="ev") for x in reverse(l)]...)
        end 

        # Mise en page
        entete = DOM.div(
            DOM.div("🦠"; class="logo"),
            DOM.div(DOM.h1("EPIDEMIC LAB"; class="titre"),
                DOM.p("LABORATOIRE DE SIMULATION · MODÈLE SEIRS"; class="sous"));
            class="entete",
        )

        gauche = DOM.div(
            DOM.div(DOM.h3("🌍 Population"), l_agents, l_inf; class="carte"),
            DOM.div(DOM.h3("🦠 Virus"), l_contag, l_lat, l_duree, l_gue, l_imm; class="carte"),
            DOM.div(DOM.h3("🛡️ Protection"), l_mask, l_vac,
                DOM.p("Stratégie de transmission"), strategy; class="carte"),
            DOM.div(DOM.h3("⏱️ Rythme"), l_vit, l_jours; class="carte"),
            b_lancer, b_pause;
            class="gauche",
        )

        droite = DOM.div(
            DOM.span(sim.statut),
            DOM.div(sim.erreur; class="erreur"),
            etats, indicateurs, progression,
            DOM.div(
                DOM.div(DOM.h3("🌍 Grille de la population"), sim.fig1; class="carte"),
                DOM.div(
                    DOM.div(DOM.h3("📰 Journal"), journal; class="carte"),
                   
                    style="flex:1; min-width:230px",
                );
                class="flex",
            ),
            DOM.div(DOM.h3("📈 Évolution"), sim.fig2; class="carte");
            class="droite",
        )

        return DOM.div(DOM.style(CSS),
            DOM.div(entete, DOM.div(gauche, droite; class="corps"); class="page"))
    end
end
