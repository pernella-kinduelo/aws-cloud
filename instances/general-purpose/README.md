# ☁️ AWS EC2 — Instances à Usage Général
### Cas concret : Plateforme E-Learning "LearnUp"

---

## 📌 Contexte

**LearnUp** est une startup proposant des formations en ligne (vidéos, quiz, certificats).  
Elle doit héberger son application sur AWS et choisir le bon type d'instance EC2.

---

## 🖥️ C'est quoi une instance EC2 ?

Une instance EC2, c'est **louer un ordinateur virtuel** dans les datacenters d'AWS.  
Tu choisis sa puissance (CPU, RAM, réseau) et tu paies à l'usage.

```
┌──────────────────────────────────────────────────────┐
│            Datacenter AWS (ex: eu-west-3 Paris)      │
│                                                      │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐        │
│  │  LearnUp  │  │  Client B │  │  Client C │  ...   │
│  │(notre app)│  │           │  │           │        │
│  └───────────┘  └───────────┘  └───────────┘        │
│                                                      │
│         → Un seul serveur physique partagé           │
│           mais chaque instance est isolée            │
└──────────────────────────────────────────────────────┘
```

---

## ⚖️ Pourquoi des instances À Usage Général ?

Les instances à usage général offrent un **équilibre entre CPU, RAM et réseau**.  
Elles sont parfaites quand aucune ressource ne domine les autres.

```
  Instance Calcul Optimisé    Instance À Usage Général    Instance Mémoire Optimisée
  ┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐
  │ CPU  ████████████ ↑  │    │ CPU  ███████░░░ =    │    │ CPU  ████░░░░░░ ↓   │
  │ RAM  ████░░░░░░ ↓    │    │ RAM  ███████░░░ =    │    │ RAM  ████████████ ↑ │
  │ NET  ████░░░░░░ ↓    │    │ NET  ███████░░░ =    │    │ NET  ████████░░░ =  │
  │                      │    │                      │    │                      │
  │ Ex: rendu vidéo,     │    │ Ex: site web, API,   │    │ Ex: base de données  │
  │ machine learning     │    │ apps légères         │    │ volumineuse, cache   │
  └──────────────────────┘    └──────────────────────┘    └──────────────────────┘
```

---

## 🏗️ Architecture de LearnUp sur AWS

```
                        ┌─────────────────────────┐
                        │    Étudiants (internet)  │
                        └────────────┬────────────┘
                                     │
                                     ▼
                        ┌─────────────────────────┐
                        │    Load Balancer AWS     │  ← Répartit le trafic
                        └────────────┬────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    ▼                                 ▼
       ┌─────────────────────┐           ┌─────────────────────┐
       │  EC2 t3.medium #1   │           │  EC2 t3.medium #2   │
       │  (Usage Général)    │           │  (Usage Général)    │
       │                     │           │                     │
       │ • Site web          │           │ • Site web          │
       │ • API cours         │           │ • API cours         │
       │ • Authentification  │           │ • Authentification  │
       └─────────────────────┘           └─────────────────────┘
                    │                                 │
                    └────────────────┬────────────────┘
                                     │
                        ┌────────────▼────────────┐
                        │   Base de données RDS   │  ← Gérée séparément
                        │ (cours, users, progrès) │
                        └─────────────────────────┘
                                     │
                        ┌────────────▼────────────┐
                        │     S3 (stockage)       │  ← Vidéos, PDFs, images
                        └─────────────────────────┘
```

---

## 📊 Choix de l'instance — Justification Architecte

| Critère | Analyse pour LearnUp |
|---|---|
| **Charge CPU** | Modérée — rendu de pages, API REST, quiz |
| **Charge RAM** | Modérée — sessions utilisateurs, cache cours |
| **Réseau** | Modéré — les vidéos sont sur S3, pas sur EC2 |
| **Conclusion** | ✅ Pas de besoin dominant → Usage Général parfait |

### Famille T vs M — Quelle différence ?

| Instance | Usage | Coût (approx.) | Quand l'utiliser |
|---|---|---|---|
| `t3.micro` | Test / dev | ~$8/mois | Environnement de développement |
| `t3.medium` | Production légère | ~$35/mois | LearnUp au lancement (<500 users/jour) |
| `t3.large` | Production croissante | ~$65/mois | LearnUp en croissance (500-2000 users/jour) |
| `m6i.large` | Production robuste | ~$90/mois | LearnUp établi (>2000 users/jour) |

> 💡 **Décision d'architecte :** On démarre avec `t3.medium` et on monitore avec **CloudWatch**.  
> Si le CPU dépasse 70% régulièrement → on scale vers `t3.large` ou `m6i.large`.

---

## 🎯 Bénéfices des instances à Usage Général pour LearnUp

**1. Flexibilité** — Un seul type d'instance gère le site, l'API et l'auth sans sur-spécialisation.

**2. Coût maîtrisé** — On ne paie pas pour 128 Go de RAM alors qu'on n'en a besoin que de 4 Go.

**3. Scalabilité simple** — En cas de pic (ex: rentrée scolaire), AWS Auto Scaling peut dupliquer les instances automatiquement.

**4. Évolutivité** — On peut migrer de `t3.medium` vers `m6i.large` sans changer l'architecture.

---

## 📈 Stratégie de montée en charge

```
Nb d'étudiants    Instance recommandée        Stratégie
─────────────────────────────────────────────────────────
0 – 200/jour  →  t3.micro (dev/test)          1 instance
200 – 500/j   →  t3.medium                    1 instance
500 – 2000/j  →  t3.large                     2 instances + Load Balancer
2000 – 5000/j →  m6i.large                    Auto Scaling Group (2-4 instances)
5000+/j       →  m6i.xlarge                   Multi-AZ + Auto Scaling
```

---

## 📂 Structure du projet

```
aws-ec2-general-purpose/
├── README.md          ← Ce fichier (documentation)
├── main.tf            ← Infrastructure Terraform
└── architecture/
    └── learnup-architecture.png  ← (à ajouter avec draw.io)
```

---

## 🔗 Ressources utiles

- [AWS EC2 Instance Types](https://aws.amazon.com/fr/ec2/instance-types/)
- [Comparateur de prix EC2](https://instances.vantage.sh/)
- [AWS Well-Architected Framework](https://aws.amazon.com/fr/architecture/well-architected/)

---

*Formation AWS Cloud Practitioner — Module 2 : Calcul dans le cloud*
