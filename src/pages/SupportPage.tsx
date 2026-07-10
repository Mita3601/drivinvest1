import {
  ArrowLeft,
  ExternalLink,
  MessageCircle,
  ShieldCheck,
} from "lucide-react";
import { useNavigate } from "react-router-dom";

const SupportPage = () => {
  const navigate = useNavigate();
  const telegramGroupLink = "https://t.me/+S0z1QeF2z4o4OGI8";
  const telegramSupportLink = "https://t.me/U_Service_client_Fujitsu";

  return (
    <div className="pb-24 space-y-5">
      <div className="flex items-center gap-3 px-4 pt-4">
        <button
          onClick={() => navigate(-1)}
          className="w-9 h-9 rounded-xl bg-secondary flex items-center justify-center"
        >
          <ArrowLeft className="w-4 h-4 text-foreground" />
        </button>
        <div>
          <h1 className="font-display font-bold text-lg text-foreground">
            Service client
          </h1>
          <p className="text-sm text-muted-foreground">
            Rejoignez le groupe Telegram pour obtenir de l’aide rapidement.
          </p>
        </div>
      </div>

      <div className="mx-4 rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/10 to-secondary p-4">
        <div className="flex items-center gap-2 text-primary">
          <ShieldCheck className="w-4 h-4" />
          <p className="text-sm font-semibold">
            Assistance rapide et sécurisée
          </p>
        </div>
        <p className="mt-2 text-sm text-muted-foreground">
          Utilisez le groupe Telegram pour poser vos questions, suivre les
          annonces et contacter le service client.
        </p>
      </div>

      <div className="mx-4 space-y-3">
        <a
          href={telegramGroupLink}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-3 rounded-2xl bg-blue-600/15 border border-blue-500/30 p-4"
        >
          <MessageCircle className="w-6 h-6 text-blue-600" />
          <div className="flex-1">
            <p className="font-bold text-foreground text-sm">
              Rejoindre le groupe Telegram
            </p>
            <p className="text-muted-foreground text-xs">
              Discutez avec la communauté et recevez des réponses rapides.
            </p>
          </div>
          <ExternalLink className="w-4 h-4 text-blue-600" />
        </a>

        <a
          href={telegramSupportLink}
          target="_blank"
          rel="noopener noreferrer"
          className="flex items-center gap-3 rounded-2xl bg-slate-100 border border-border p-4"
        >
          <MessageCircle className="w-6 h-6 text-foreground" />
          <div className="flex-1">
            <p className="font-bold text-foreground text-sm">
              Service client Telegram
            </p>
            <p className="text-muted-foreground text-xs">
              Contacter directement l’assistance via Telegram.
            </p>
          </div>
          <ExternalLink className="w-4 h-4 text-foreground" />
        </a>
      </div>
    </div>
  );
};

export default SupportPage;
