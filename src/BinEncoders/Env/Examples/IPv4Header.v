Require Import
        Coq.Strings.String
        Coq.Vectors.Vector.

Require Import
        Fiat.Common.SumType
        Fiat.Common.EnumType
        Fiat.Common.BoundedLookup
        Fiat.Common.ilist
        Fiat.Computation
        Fiat.QueryStructure.Specification.Representation.Notations
        Fiat.QueryStructure.Specification.Representation.Heading
        Fiat.QueryStructure.Specification.Representation.Tuple
        Fiat.BinEncoders.Env.BinLib.Core
        Fiat.BinEncoders.Env.Common.Specs
        Fiat.BinEncoders.Env.Common.WordFacts
        Fiat.BinEncoders.Env.Common.ComposeCheckSum
        Fiat.BinEncoders.Env.Common.ComposeIf
        Fiat.BinEncoders.Env.Common.ComposeOpt
        Fiat.BinEncoders.Env.Automation.Solver
        Fiat.BinEncoders.Env.Lib2.FixListOpt
        Fiat.BinEncoders.Env.Lib2.NoCache
        Fiat.BinEncoders.Env.Lib2.WordOpt
        Fiat.BinEncoders.Env.Lib2.Bool
        Fiat.BinEncoders.Env.Lib2.NatOpt
        Fiat.BinEncoders.Env.Lib2.Vector
        Fiat.BinEncoders.Env.Lib2.EnumOpt
        Fiat.BinEncoders.Env.Lib2.SumTypeOpt
        Fiat.BinEncoders.Env.Lib2.IPChecksum.

Require Import Bedrock.Word.

Import Vectors.VectorDef.VectorNotations.
Open Scope string_scope.
Open Scope Tuple_scope.

(* Start Example Derivation. *)

Definition IPv4_Packet :=
  @Tuple <"TotalLength" :: word 16,
          "ID" :: word 16,
          "DF" :: bool, (* Don't fragment flag *)
          "MF" :: bool, (*  Multiple fragments flag *)
          "FragmentOffset" :: word 13,
          "TTL" :: char,
          "Protocol" :: EnumType ["ICMP"; "TCP"; "UDP"],
          (* So many to choose from: http://www.iana.org/assignments/protocol-numbers/protocol-numbers.xhtml*)
          "SourceAddress" :: word 32,
          "DestAddress" :: word 32,
          "Options" :: list (word 32)>.

Definition ProtocolTypeCodes : Vector.t char 3 :=
  [WO~0~0~0~0~0~0~0~1;
   WO~0~0~0~0~0~1~1~0;
   WO~0~0~0~1~0~0~0~1
  ].

Definition IPv4_Packet_Header_Len (ip4 : IPv4_Packet) := 5 + |ip4!"Options"|.

Definition encode_IPv4_Packet_Spec (ip4 : IPv4_Packet)  :=
          (encode_word_Spec (natToWord 4 4)
    ThenC encode_nat_Spec 4 (IPv4_Packet_Header_Len ip4)
    ThenC encode_unused_word_Spec 8 (* TOS Field! *)
    ThenC encode_word_Spec ip4!"TotalLength"
    ThenC encode_word_Spec ip4!"ID"
    ThenC encode_unused_word_Spec 1 (* Unused flag! *)
    ThenC encode_bool_Spec ip4!"DF"
    ThenC encode_bool_Spec ip4!"MF"
    ThenC encode_word_Spec ip4!"FragmentOffset"
    ThenC encode_word_Spec ip4!"TTL"
    ThenC encode_enum_Spec ProtocolTypeCodes ip4!"Protocol"
    DoneC)
    ThenChecksum IPChecksum_Valid OfSize 16
    ThenCarryOn (encode_word_Spec ip4!"SourceAddress"
    ThenC encode_word_Spec ip4!"DestAddress"
    ThenC encode_list_Spec encode_word_Spec ip4!"Options"
    DoneC).

Definition IPv4_Packet_OK (ipv4 : IPv4_Packet) :=
  lt (|ipv4!"Options"|) 11 /\
  lt (20 + 4 * |ipv4!"Options"|) (wordToNat ipv4!"TotalLength").

Definition IPv4_Packet_encoded_measure (ipv4_b : ByteString)
  : nat :=
  match (`(u, b') <- decode_unused_word' 4 ipv4_b;
           decode_word' 4 b') with
  | Some n => 32 * wordToNat (fst n)
  | None => 0
  end.

Arguments mult : simpl never.
Arguments decode_word' : simpl never.

Lemma IPv4_Packet_Headiner_Len_Bound
  : forall (a : IPv4_Packet) (a_OK : IPv4_Packet_OK a),
    BinNat.N.lt (BinNat.N.of_nat (IPv4_Packet_Header_Len a)) (Npow2 4).
Proof.
  unfold IPv4_Packet_Header_Len.
  intros; unfold IPv4_Packet_OK in a_OK.
  destruct a_OK.
  rewrite <- BinNat.N.compare_lt_iff.
  rewrite Nnat.N2Nat.inj_compare.
  rewrite Nnat.Nat2N.id.
  rewrite <- Compare_dec.nat_compare_lt.
  simpl.
  unfold BinPos.Pos.to_nat; simpl.
  auto with arith.
Qed.

Lemma IPv4_Packet_Header_Len_eq
  : forall data len,
    IPv4_Packet_Header_Len data = len
    -> ((|data!"Options" |) = len - 5).
Proof.
  unfold IPv4_Packet_Header_Len; intros.
  apply Minus.plus_minus.
  rewrite H; reflexivity.
Qed.

Lemma IPv4_Packet_Header_Len_OK
  : forall ip4 (ctx ctx' ctx'' : CacheEncode) c b b'' ext,
    (encode_word_Spec (natToWord 4 4)
    ThenC encode_nat_Spec 4 (IPv4_Packet_Header_Len ip4)
    ThenC encode_unused_word_Spec 8 (* TOS Field! *)
    ThenC encode_word_Spec ip4!"TotalLength"
    ThenC encode_word_Spec ip4!"ID"
    ThenC encode_unused_word_Spec 1 (* Unused flag! *)
    ThenC encode_bool_Spec ip4!"DF"
    ThenC encode_bool_Spec ip4!"MF"
    ThenC encode_word_Spec ip4!"FragmentOffset"
    ThenC encode_word_Spec ip4!"TTL"
    ThenC encode_enum_Spec ProtocolTypeCodes ip4!"Protocol"
    DoneC) ctx ↝ (b, ctx') ->
    (encode_word_Spec ip4!"SourceAddress"
    ThenC encode_word_Spec ip4!"DestAddress"
    ThenC encode_list_Spec encode_word_Spec ip4!"Options"
    DoneC) ctx' ↝ (b'', ctx'') ->
    IPv4_Packet_OK ip4 ->
    (fun _ => 128) ip4 + (fun a => 16 + |ip4!"Options"| * 32) ip4 + (bin_measure transform_id) + 16 = IPv4_Packet_encoded_measure (transform (transform b (transform (encode_checksum _ _ _ 16 c) b'')) ext).
Proof.
  intros.
  set (k := transform_id); simpl in k; subst k.
  simpl bin_measure.
  rewrite length_ByteString_id.
  unfold IPv4_Packet_encoded_measure.
  pose proof transform_assoc as H'; simpl in H';
    rewrite <- !H'.
  eapply computes_to_compose_decode_unused_word in H;
    let H' := fresh in
    destruct H as [? [? [? H'] ] ]; rewrite H'.
  unfold DecodeBindOpt, If_Opt_Then_Else.
  eapply computes_to_compose_decode_word in H;
    let H' := fresh in
    destruct H as [? [? [? H'] ] ]; rewrite H'.
  unfold fst.
  rewrite wordToNat_natToWord_idempotent; try reflexivity;
    eauto using IPv4_Packet_Headiner_Len_Bound.
  unfold IPv4_Packet_Header_Len.
  rewrite Mult.mult_plus_distr_l.
  omega.
Qed.

Hint Resolve IPv4_Packet_Header_Len_eq : data_inv_hints.


Local Arguments transform_id / .
Local Arguments NPeano.modulo : simpl never.

Definition EthernetHeader_decoder
  : CorrectDecoderFor IPv4_Packet_OK encode_IPv4_Packet_Spec.
Proof.
  start_synthesizing_decoder.
  normalize_compose transformer.
  apply_IPChecksum IPv4_Packet_Header_Len_OK.
  
  simpl; unfold IPv4_Packet_OK; clear; intros ? H'; destruct H' as [? ?]; repeat split.
  simpl; unfold IPv4_Packet_Header_Len.
  revert H; unfold StringId11; unfold pow2, mult; simpl; auto with arith.

  repeat (decode_step; unfold Domain; simpl).
  synthesize_cache_invariant.

  repeat optimize_decoder_impl.

Defined.

Definition IPv4_decoder_impl :=
  Eval simpl in (fst (proj1_sig EthernetHeader_decoder)).

Definition pkt' : list char :=
  [WO~1~0~1~0~0~0~1~0;
   WO~0~0~0~0~0~0~0~0;

   WO~0~0~0~0~0~0~0~0;
   WO~0~0~0~0~0~0~0~0;

   WO~0~0~0~0~0~0~0~0;
   WO~0~0~0~0~0~0~0~0;

   WO~0~0~0~0~0~0~0~0;
   WO~0~0~0~0~0~0~0~0;

   WO~0~1~1~0~0~1~0~0;
   WO~1~0~0~0~0~0~0~0;

   WO~0~0~0~0~0~0~0~0;
   WO~0~0~0~0~0~0~0~0;

   WO~0~0~0~0~0~0~1~1;
   WO~0~0~0~1~0~1~0~1;

   WO~0~1~1~1~1~0~1~1;
   WO~0~1~0~1~0~0~0~0;

   WO~0~0~0~0~0~0~1~1;
   WO~0~0~0~1~0~1~0~1;

   WO~0~1~1~1~1~0~1~1;
   WO~1~0~0~0~0~0~0~0]%list.

Definition pkt : list char :=
    Eval compute in map (@natToWord 8) [69;0;100;0;0;0;0;0;38;1;243;159;192;168;222;10;192;168;222;1;0;0;0;0].

Compute (InternetChecksum.checksum pkt).

Definition address : list char :=
  Eval compute in map (@natToWord 8) [172;16;254;1].

Lemma zero_lt_eight : (lt 0 8)%nat.
Proof. omega. Qed.

Definition fiat_ipv4_decode (buffer: list char) : option (IPv4_Packet * list char) :=
  let bs := {| padding := 0; front := WO; paddingOK := zero_lt_eight; byteString := buffer |} in
  match IPv4_decoder_impl bs () with
  | Some (pkt', bs, _) => Some (pkt', bs.(byteString))
  | None => None
  end.

Compute (fiat_ipv4_decode pkt).

Compute (InternetChecksum.checksum pkt).
