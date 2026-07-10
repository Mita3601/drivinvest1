import { ArrowLeft, Cpu } from "lucide-react";
import { useNavigate } from "react-router-dom";

const AboutPage = () => {
  const navigate = useNavigate();
  return (
    <div className="pb-24 space-y-5">
      <div className="flex items-center gap-3 px-4 pt-4">
        <button
          onClick={() => navigate(-1)}
          className="w-9 h-9 rounded-xl bg-secondary flex items-center justify-center"
        >
          <ArrowLeft className="w-4 h-4 text-foreground" />
        </button>
        <h1 className="font-display font-bold text-lg text-foreground">
          À propos de nous
        </h1>
      </div>
      <div className="mx-4 rounded-2xl bg-secondary border border-border p-6 space-y-4">
        <div className="flex items-center gap-3">
          <Cpu className="w-8 h-8 text-primary" />
          <h2 className="font-display font-bold text-xl text-gradient-gold">
            Fujitsu
          </h2>
        </div>
        <p className="text-foreground text-sm leading-relaxed">
          Fujitsu est une plateforme d'investissement innovante conçue pour
          mettre à la portée de chacun des opportunités concrètes et rentables
          dans le secteur de la haute technologie. Nous accompagnons nos clients
          dans l'acquisition de produits technologiques de pointe, notamment des
          ordinateurs portables, des stations de travail et des PC gaming
          nouvelle génération, avec une approche pensée pour offrir à la fois
          performance, valeur durable et visibilité sur chaque projet.
        </p>
        <p className="text-muted-foreground text-sm leading-relaxed">
          Chez Fujitsu, nous croyons que l'investissement doit être simple,
          transparent et accessible. C'est pourquoi nous avons mis en place un
          système de parrainage à 3 niveaux, permettant à chaque membre de
          développer son réseau, de partager des opportunités et de maximiser
          ses gains grâce à une communauté dynamique et engagée.
        </p>
        <p className="text-muted-foreground text-sm leading-relaxed">
          Notre vision est claire : offrir un environnement sécurisé, fiable et
          orienté résultats, où chaque utilisateur peut évoluer avec confiance.
          Sécurité, transparence, rentabilité et accompagnement sont au cœur de
          notre mission. Rejoignez la communauté Fujitsu et faites grandir votre
          capital avec une plateforme qui allie innovation, sérieux et potentiel
          de croissance à long terme.
        </p>
      </div>
    </div>
  );
};

export default AboutPage;
