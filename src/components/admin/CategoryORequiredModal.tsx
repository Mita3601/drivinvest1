import { AlertTriangle, ArrowRight } from "lucide-react";
import { Button } from "@/components/ui/button";

interface CategoryORequiredModalProps {
  onNavigateToCategoryO: () => void;
  isOpen: boolean;
}

export const CategoryORequiredModal = ({
  onNavigateToCategoryO,
  isOpen,
}: CategoryORequiredModalProps) => {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-background rounded-2xl border border-border max-w-md w-full p-6 space-y-4">
        <div className="flex items-center gap-3 text-destructive">
          <AlertTriangle className="w-6 h-6" />
          <h2 className="font-bold text-lg">Accès restreint</h2>
        </div>

        <p className="text-foreground text-sm leading-relaxed">
          Vous devez d'abord acheter un{" "}
          <span className="font-bold">Pack Obligatoire</span> avant de pouvoir
          accéder aux autres produits.
        </p>

        <div className="bg-primary/10 border border-primary/30 rounded-lg p-3 text-xs text-foreground space-y-1">
          <p className="font-bold">Packs Obligatoires disponibles:</p>
          <ul className="list-disc list-inside text-muted-foreground space-y-0.5">
            <li>1 000 F - Remboursé 3 500 F après 3 semaines</li>
            <li>2 500 F - Remboursé 8 750 F après 3 semaines</li>
            <li>3 000 F - Remboursé 10 500 F après 3 semaines</li>
            <li>4 000 F - Remboursé 14 000 F après 3 semaines</li>
            <li>7 000 F - Remboursé 24 500 F après 3 semaines</li>
          </ul>
        </div>

        <Button
          onClick={onNavigateToCategoryO}
          className="w-full bg-primary text-primary-foreground font-bold flex items-center justify-center gap-2"
        >
          <span>Acheter maintenant</span>
          <ArrowRight className="w-4 h-4" />
        </Button>
      </div>
    </div>
  );
};
