---
title: Identity and permissions
description: ATProto OAuth, DPoP, permission sets, and owner-mediated writes.
---

> This page defines the MVP security contract. The bootstrap has permission-set
> models and tested PKCE/DPoP/XRPC primitives, but no authenticated web BFF,
> native OAuth session, or owner-mediated write executor.

Web clients use a token-holding backend-for-frontend with HTTP-only sessions. Apple and Android clients use PKCE and DPoP directly. Provider credentials never enter the client-accessible ATProto record layer.

Permission sets are progressive and product-specific. Read-only discovery cannot silently acquire record creation or provider administration authority.

Collaborators submit scoped XRPC mutations. Atelier checks actor identity, the owner’s ACL, record revision, and requested fields before using an owner-authorized session to write the canonical record. Actor-owned comments and relationships stay in the actor’s own PDS.
