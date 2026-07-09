# Correction du problème de retrait - Guide de déploiement

## Problème identifié

L'utilisateur recevait l'erreur **"Modification non autorisée d'un champ sensible du profil"** lors d'une tentative de retrait.

## Causes

1. **Condition manquante** : La fonction `request_withdrawal` ne vérifiait pas si l'utilisateur possédait au moins un produit d'investissement actif
2. **Problème de contexte** : Le trigger `protect_profile_sensitive_fields()` bloquait les modifications du solde même lors d'un appel RPC autorisé

## Solutions implémentées

### Nouvelle migration créée

- Fichier : `supabase/migrations/20260709_fix_withdrawal_and_trigger.sql`

### Changements effectués

1. **Correction du trigger `protect_profile_sensitive_fields()`**
   - Amélioration de la gestion du contexte `app.internal_call`
   - Ajout de vérifications supplémentaires pour les appels RPC

2. **Amélioration de la fonction `request_withdrawal()`**
   - ✅ Ajout de la vérification d'investissement actif
   - ✅ Amélior du paramètre de contexte dans le header SET
   - Erreur retournée si l'utilisateur n'a pas au moins un produit actif :
     ```
     "Vous devez posséder au moins un produit actif pour effectuer un retrait."
     ```

3. **Gestion des permissions**
   - Permissions mises à jour pour les utilisateurs authentifiés

## Déploiement sur Supabase

### Option 1 : Via CLI (Recommandé)

```bash
cd ~/Bureau/drivinvest1
npx supabase link  # Lier le projet
npx supabase migration up  # Déployer les migrations
```

### Option 2 : Via le Dashboard Supabase (Manuel)

1. Aller sur https://supabase.com/dashboard
2. Sélectionner le projet "drivinvest1"
3. Aller dans SQL Editor
4. Copier le contenu de `supabase/migrations/20260709_fix_withdrawal_and_trigger.sql`
5. Exécuter le script SQL

## Vérification du correctif

Après le déploiement, testez le retrait :

1. **Cas 1 - Utilisateur SANS produit actif**
   - Résultat attendu : Erreur "Vous devez posséder au moins un produit actif pour effectuer un retrait."

2. **Cas 2 - Utilisateur AVEC produit actif et solde suffisant**
   - Résultat attendu : Le retrait doit être traité normalement

3. **Cas 3 - Utilisateur AVEC produit actif mais solde insuffisant**
   - Résultat attendu : Erreur "Solde insuffisant"

## Files modifiés/créés

- ✅ `supabase/migrations/20260709_fix_withdrawal_and_trigger.sql` (nouvelle)
- ✅ `supabase/migrations/20260702120000_reconfigure_products_and_withdrawals.sql` (révert à l'état original)

## Notes importantes

- Le changement s'applique uniquement au backend Supabase
- Aucune modification du code React/Frontend n'est nécessaire
- La migration est sans danger et peut être appliquée en production
