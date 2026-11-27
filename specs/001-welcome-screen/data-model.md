# Data Model: Welcome Screen

One persisted value: the instance address.

## Instance

The Monica server the app will talk to.

| Field | Type | Rule |
| --- | --- | --- |
| url | text | Absolute `http` or `https` address with a host, no trailing slash. Default `https://app.monicahq.com`. Stored in `UserDefaults` under `instance_url`; absent means default. |
| host (derived) | text | The url without its scheme and without a trailing slash: `https://app.monicahq.com/` → `app.monicahq.com`. Keeps a port or a path (`http://localhost:8000/monica` → `localhost:8000/monica`). |

**Normalisation of what the person types** (`normalizeInstanceURL`): trim spaces; empty → default;
any space left → refused; no `://` → prefix `https://`; remove trailing slashes; refused (nil)
unless the scheme is `http` or `https` and there is a host.

## Welcome UI state

| Field | Type | Rule |
| --- | --- | --- |
| instanceURL | text | The saved `Instance.url`. |
| sheet | InstanceSheetState or none | None when the sheet is closed. |
| sheet.draft | text | What the field shows; starts as `instanceURL` when the sheet opens. |
| sheet.isError | yes/no | True after a save with an invalid draft; false again as soon as the draft changes. |

## Strings

Every text of the screen, in each supported language, in `Monica/Resources/Localizable.xcstrings`.
Keys are shared by all languages, and with the Android app.

| Key | English (source) | French |
| --- | --- | --- |
| `app_name` | Monica | Monica |
| `welcome_title` | Welcome to Monica | Bienvenue dans Monica |
| `welcome_description` | Monica helps you remember and organise your relationships and life context. | Monica vous aide à vous souvenir et à organiser vos relations et votre contexte de vie. |
| `welcome_sign_up` | Sign up | Inscription |
| `welcome_log_in` | Log in | Connexion |
| `welcome_instance` | Instance: %@ | Instance : %@ (with a non-breaking space before the colon) |
| `welcome_instance_settings` | Instance settings | Paramètres de l'instance |
| `welcome_illustration` | A panda sitting in the grass, waving | Un panda assis dans l'herbe qui fait coucou |
| `instance_sheet_title` | Instance URL | URL de l'instance |
| `instance_sheet_description` | The address of the Monica server the app connects to. Keep the default to use the hosted service, or enter the address of your own instance. | L'adresse du serveur Monica auquel l'app se connecte. Laissez la valeur par défaut pour utiliser le service hébergé, ou saisissez celle de votre propre instance. |
| `instance_sheet_address` | Address | Adresse |
| `instance_sheet_placeholder` | https://monica.example.com | https://monica.exemple.fr |
| `instance_sheet_invalid` | Enter an address like https://monica.example.com | Saisissez une adresse comme https://monica.exemple.fr |
| `instance_sheet_reset` | Reset to default | Rétablir par défaut |
| `instance_sheet_cancel` | Cancel | Annuler |
| `instance_sheet_save` | Save | Sauvegarder |

`app_name` is the same in both languages but listed in each: iOS shows the key itself, not the
English text, when a language's table lacks it. The placeholder string `welcome` ("Welcome to
Monica") is removed.
