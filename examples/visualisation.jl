
const NOMS = ["Sains", "Exposés", "Infectés", "Guéris"]
const COULEURS = [:deepskyblue, :orange, :crimson, :limegreen]
const FOND = RGBf(0.06, 0.08, 0.19)

# État d'un agent : 1 sain, 2 exposé, 3 infecté, 4 guéri
etat(a) = Int(a.status) + 1

# Nombre d'agents par état -> [sains, exposés, infectés, guéris]
compter(model) = [count(a -> etat(a) == i, allagents(model)) for i in 1:4]

# Crée le modèle à partir des curseurs de la page
function creer_modele(ctrl)
    n = Int(ctrl.s_agents.value[])
    mode = string(ctrl.strategy.value[]) == "Classique" ?
           Epidemic.BasicTransmission : Epidemic.ProtectedTransmission
    return initialize_model(
        n_agents=n,
        initial_infected=min(Int(ctrl.s_inf.value[]), n),
        infectiousness=ctrl.s_contag.value[],
        latency_period=Int(ctrl.s_lat.value[]),
        duration=Int(ctrl.s_duree.value[]),
        chance_recover=ctrl.s_gue.value[],
        immunity_duration=Int(ctrl.s_imm.value[]),
        mask_probability=ctrl.s_mask.value[],
        vaccination_probability=ctrl.s_vac.value[],
        strategy=mode,
    )
end

# Avance d'un jour et renvoie le nombre de morts
# (un agent qui disparaît pendant le pas est mort ; les naissances n'y changent rien)
function un_jour!(model)
    avant = Set(a.id for a in allagents(model))
    Agents.step!(model, 1)
    apres = Set(a.id for a in allagents(model))
    return length(setdiff(avant, apres))
end

function creer_simulation(ctrl)

    # ----- Valeurs affichées sur la page -----
    compte = Observable([0, 0, 0, 0])
    indic = Observable(["0", "-", "0", "0 %"])   # pic, jour du pic, décès, immunisés
    progression = Observable(0.0)
    alerte_prog = Observable(false)
    lignes = Observable(String[])                # journal
    statut = Observable("En attente du lancement")
    erreur = Observable("")

    # ----- Grille des agents -----
    pts = Observable(Point2f[])
    cols = Observable(Int[])
    fig1 = Figure(size=(700, 540), backgroundcolor=:transparent)
    ax = Axis(fig1[1, 1]; aspect=DataAspect(), backgroundcolor=FOND)
    hidedecorations!(ax)
    scatter!(ax, pts; color=cols, colormap=COULEURS, colorrange=(1, 4), markersize=14)

    # ----- Courbes -----
    courbes = [Observable(Point2f[]) for _ in 1:4]
    pic_pt = Observable(Point2f[])               # position de l'étoile sur le pic
    fig2 = Figure(size=(1020, 300), backgroundcolor=:transparent)
    ax2 = Axis(fig2[1, 1]; xlabel="Jour", ylabel="Personnes", backgroundcolor=FOND)
    for i in 1:4
        lines!(ax2, courbes[i]; color=COULEURS[i], linewidth=3, label=NOMS[i])
    end
    scatter!(ax2, pic_pt; marker=:star5, markersize=20, color=:white,
        strokewidth=2, strokecolor=:crimson)
    axislegend(ax2; position=:rt)

    # ----- Suivi -----
    en_cours, pause, stop = Ref(false), Ref(false), Ref(false)
    pic, jour_pic = Ref(0), Ref(0)    # plus grand nombre d'infectés et son jour
    deja = Set{Symbol}()              # événements déjà notés dans le journal

    # Ajoute un message au journal (8 lignes maximum)
    function noter!(msg)
        l = copy(lignes[])
        push!(l, msg)
        length(l) > 8 && popfirst!(l)
        lignes[] = l
    end

    # Note un message une seule fois
    function une_fois!(cle, msg)
        cle in deja && return
        push!(deja, cle)
        noter!(msg)
    end

    # Met l'écran à jour pour un jour donné et renvoie les effectifs
    function afficher(model, jour, morts, nj)
        agents = collect(allagents(model))
        pts[] = [Point2f(a.pos...) for a in agents]
        cols[] = [etat(a) for a in agents]

        c = compter(model)
        total = max(sum(c), 1)
        compte[] = c
        for i in 1:4
            courbes[i][] = push!(courbes[i][], Point2f(jour, c[i]))
        end
        reset_limits!(ax2)

        # Journal et étoile du pic
        if c[3] > pic[]
            pic[] = c[3]; jour_pic[] = jour
            pic_pt[] = [Point2f(jour, c[3])]
        elseif pic[] > 0 && c[3] < pic[]
            une_fois!(:pic, "Jour $jour : le pic est passé ($(pic[]) infectés au jour $(jour_pic[])).")
        end
        jour == 0 && noter!("Jour 0 : départ avec $(c[3]) infectés sur $total personnes.")
        c[3] > 0.3 * total && une_fois!(:alerte, "Jour $jour : alerte, plus de 30 % d'infectés !")
        morts > 0 && une_fois!(:deces, "Jour $jour : premier décès.")

        indic[] = ["$(pic[])", pic[] > 0 ? "$(jour_pic[])" : "-", "$morts",
                   "$(round(Int, 100 * c[4] / total)) %"]
        progression[] = 100 * jour / nj
        alerte_prog[] = c[3] > 0.3 * total
        statut[] = "Jour $jour / $nj  -  Décès : $morts"
        return c
    end
     
    # Lance une simulation complète
    function lancer()
        if en_cours[]                      # arrête l'ancienne simulation
            stop[] = true
            while en_cours[]
                sleep(0.05)
            end
        end
        stop[] = false; pause[] = false; en_cours[] = true

        try
            erreur[] = ""
            nj = Int(ctrl.s_jours.value[])
            model = creer_modele(ctrl)

            # Remise à zéro
            foreach(c -> c[] = Point2f[], courbes)
            pic_pt[] = Point2f[]; lignes[] = String[]
            pic[] = 0; jour_pic[] = 0; empty!(deja)
            morts = 0

            for jour in 0:nj               # un tour de boucle = un jour
                while pause[] && !stop[]
                    sleep(0.1)
                end
                stop[] && break

                c = afficher(model, jour, morts, nj)

                if jour > 0 && c[2] + c[3] == 0    # plus aucun exposé ni infecté
                    noter!("Jour $jour : l'épidémie est terminée.")
                    statut[] = "Épidémie terminée au jour $jour  -  Décès : $morts"
                    break
                end
                if jour == nj
                    statut[] = "Terminée  -  " * statut[]
                    break
                end

                morts += un_jour!(model)
                sleep(0.6 / ctrl.s_vit.value[])
            end
        catch e
            erreur[] = "Erreur : " * sprint(showerror, e)
            statut[] = "La simulation a échoué"
            showerror(stderr, e, catch_backtrace())
        finally
            en_cours[] = false
        end
    end

    return (; compte, indic, progression, alerte_prog, lignes, statut, erreur,
             fig1, fig2, lancer, pause, en_cours)
end
