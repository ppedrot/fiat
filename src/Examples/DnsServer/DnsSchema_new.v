Require Import Coq.Vectors.Vector
        Coq.Strings.Ascii Coq.Bool.Bool
        Coq.Bool.Bvector Coq.Lists.List.

Require Import
        Fiat.QueryStructure.Automation.AutoDB
        Fiat.Examples.DnsServer.packet.

Definition sREQUESTS := "Requests".
Definition sSTAGE := "Stage".
Definition sID := "ID".
Definition IP := name.
Definition sIP := "IP".
Definition sRESULT := "Result".
Definition sDOMAIN := "Domain".
(* the # prefix it's on, from front? or back? *)
(* Definition sTIME := "Time". *)
(* everything added gets an unique ID already *)

Definition Stage := option nat.
Definition id : Type := nat.
Definition server := name.      (* both IP and server name *)

(* need this because there's no way to encode failure (no questions) in a packet *)
Inductive WrapperResponse : Type :=
(* TODO add SOL fields *)
| Question : server -> packet -> WrapperResponse
| Answer : packet -> WrapperResponse
| Failure : packet -> SOA -> WrapperResponse.

(* Which section of a packet a certain answer (DNSRRecord) is in. *)
Inductive PacketSection : Type :=
| PAnswer : PacketSection
| PAuthority : PacketSection
| PAdditional : PacketSection.

Definition sCACHE_POINTERS := "Cache pointers to tables".
Definition sCACHE_REFERRALS := "Cached referrals".
Definition sCACHE_ANSWERS := "Cached answers".
Definition sCACHE_FAILURES := "Cached failures".
Definition sPACKET_SECTION := "Packet section".
Definition sSERVER := "Server". (* the server in a Question WrapperResponse *)
Definition sPID := "Packet id".
Definition sFLAGS := "Packet flags".
Definition sNAME := "Record name". (* record string redefined here for clarity *)
   (* this should be the IP (if not a reverse lookup) *)
Definition sTYPE := "Record type".
Definition sCLASS := "Record class".
Definition sTTL := "Record TTL".
Definition sRDATA := "Record RDATA".

(* SOA record fields *)
Definition sHOST := "Source host".
Definition sEMAIL := "Contact email".
Definition sSERIAL := "Serial number".
Definition sREFRESH := "Refresh time".
Definition sRETRY := "Retry time".
Definition sEXPIRE := "Expire time".
Definition sMinTTL := "Minimum TTL".
Definition sPACKET := "Packet".

Definition sREFERRALDOMAIN := "Referral domain".
Definition sRTYPE := "Referral domain type".
Definition sRCLASS := "Referral domain class".
Definition sRTTL := "Referral domain TTL".
Definition sSERVERDOMAIN := "Server domain".
Definition sSTYPE := "Server type".
Definition sSCLASS := "Server class".
Definition sSTTL := "Server TTL".
Definition sSIP := "Server IP".

Definition sQNAME := "Question name".
Definition sQTYPE := "Question type".
Definition sQCLASS := "Question class".
Definition sCACHETABLE := "Cache table".

(* The ideal schema would be domain and WrapperResponse, with some way to query the types nested in WrapperResponse. Flattening it here has the same effect. 

One (Domain => WrapperResponse) mapping is flattened into several rows that all have the same packet information, but store one answer (DNSRRecord) each. 

When removing a (Domain => WrapperResponse):
delete rows with the Domain in all cache tables.

When inserting/updating a new (Domain => WrapperResponse):
after checking that Domain doesn't exist in any of the cache tables (or just performing a delete), flatten it and insert each row. 

Invariants: (TODO)
- All rows for each domain should appear in exactly 1 of the cache relations (question, answer, or failure). We do not store multiple possibilities.
- All rows for each domain should have the same packet info. *)

Definition ReferralHeading :=
  (* R- = referral domain's, S- = server domain's *)
         <sPID :: Bvector 16,
          sFLAGS :: Bvector 16,
          sQNAME :: name,
          sQTYPE :: RRecordType,
          sQCLASS :: RRecordClass,
          sREFERRALDOMAIN :: name,
          sRTYPE :: RRecordType,
          sRCLASS :: RRecordClass,
          sRTTL :: nat,
          (* inline RDATA and additional record *)
          sSERVERDOMAIN :: name,
          sSTYPE :: RRecordType,
          sSCLASS :: RRecordClass,
          sSTTL :: nat,
          sSIP :: name
          (* IP in RDATA of additional record *)
         >%Heading.

(* stores an answer (DNSRRecord) *)
Definition AnswerHeading :=
         <sDOMAIN :: name,
          sPACKET_SECTION :: PacketSection,
          sPID :: Bvector 16,
          sFLAGS :: Bvector 16,
          sQNAME :: name,
          sQTYPE :: RRecordType,
          sQCLASS :: RRecordClass,
          sNAME :: name,
          sTYPE :: RRecordType,
          sCLASS :: RRecordClass,
          sTTL :: nat,
          sRDATA :: name
         >%Heading.
          (* stores an SOA record according to RFC 2308 *)
          (* the SOA is technically supposed to go in the Authority section but the packet type doesn't include it *)

Definition FailureHeading :=
          <sDOMAIN :: name,
           sPID :: Bvector 16,
           sFLAGS :: Bvector 16,
           sHOST :: name,
           sEMAIL :: name,
           sSERIAL :: nat,
           sREFRESH :: nat,
           sRETRY :: nat,
           sEXPIRE :: nat,
           sMinTTL :: nat
          >%Heading.

Definition ReferralRow := @Tuple ReferralHeading.
Definition AnswerRow := @Tuple AnswerHeading.
Definition FailureRow :=
  @Tuple FailureHeading.

(* TODO: remove extraneous packet fields
when we query here, we want a result type
that later gets combined with the actual packet in Process
Process gets ALL the rows from one table (or none)
 *)

(* so we can return a list of rows from any table *)
Inductive CacheResult :=
(* TODO: hack to make DeleteResultForDomain check *)
| Nope : list ReferralRow -> CacheResult
(* Nonempty lists *)
| Ref : list ReferralRow -> CacheResult
| Ans : list AnswerRow -> CacheResult
| Fail : option FailureRow -> CacheResult.

Inductive CacheTable :=
| CReferrals
| CAnswers
| CFailures.

Definition DnsRecSchema :=
  Query Structure Schema
        [ relation sCACHE_POINTERS has schema
                   < sDOMAIN :: name,
                     sCACHETABLE :: CacheTable
                   > ;
          relation sCACHE_REFERRALS has
                   schema
                   ReferralHeading;
          relation sCACHE_ANSWERS has
                   schema
                   AnswerHeading;
          relation sCACHE_FAILURES has
                   schema
                   FailureHeading;
          relation sREQUESTS has
                   schema
                  < sID :: id,  (* unique, ascending *)
          (* TODO add the other fields *)
                    sNAME :: name,
                    sSTAGE :: Stage
                  > ]
          (* where (fun t t' => True) ] *)
        (* can i have an invariant that just works on one tuple?
         i want to encode that Stage <= length name *)
        (* use an attribute constraint TODO *)
        enforcing [ ]. 

Check DnsRecSchema.