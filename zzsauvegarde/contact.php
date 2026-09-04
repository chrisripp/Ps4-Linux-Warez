<?php
/**
 * Traitement basique du formulaire de contact.
 * Compatible avec l'hébergement mutualisé free.fr (PHP + mail()).
 * À adapter : adresse e-mail de destination, redirection, anti-spam.
 */

header('Content-Type: text/html; charset=utf-8');

$destinataire = "contact@ps4-linux-warez.free.fr"; // <-- à remplacer par ta vraie adresse

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: contact.html');
    exit;
}

function clean($v) {
    return htmlspecialchars(trim($v ?? ''), ENT_QUOTES, 'UTF-8');
}

$nom     = clean($_POST['nom'] ?? '');
$email   = filter_var(trim($_POST['email'] ?? ''), FILTER_VALIDATE_EMAIL);
$sujet   = clean($_POST['sujet'] ?? 'Contact Ps4-Linux-Warez');
$message = clean($_POST['message'] ?? '');

if ($nom === '' || !$email || $message === '') {
    echo "Merci de remplir correctement le formulaire. <a href='contact.html'>Retour</a>";
    exit;
}

$corps = "Nom : $nom\nE-mail : $email\n\nMessage :\n$message\n";
$headers = "From: no-reply@ps4-linux-warez.free.fr\r\nReply-To: $email\r\n";

if (mail($destinataire, "[Ps4-Linux-Warez] $sujet", $corps, $headers)) {
    echo "Message envoyé, merci ! <a href='contact.html'>Retour au site</a>";
} else {
    echo "Erreur d'envoi. Réessaie plus tard. <a href='contact.html'>Retour</a>";
}
