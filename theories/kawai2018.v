From mathcomp Require Import all_ssreflect.
Require Import Program.
From Equations Require Import Equations.
Require Import extra_principles.
Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.
Require Import Lia.

Require Import continuity_zoo_Prop.
Require Import Brouwer_ext.
Require Import BI.


Set Bullet Behavior "Strict Subproofs".
Set Default Goal Selector "!".


(** Kawaii's "Principles of bar induction and continuity on Baire space" has the notions of
    neighborhood function and Brouwer operation, and derives continuity notions based on them.
    Brouwer operations are an inductive _predicate_ on neighborhood functions.

Result 1: a neighborhood function is just a valid Brouwer extensional tree,
       thus neigh_cont is equivalent to Bseq_cont_valid. We prove this in 
            Theorem neigh_cont_Bseq_cont.

Result 2: a Brouwer operation can be turned into the existence of a Brouwer tree 
       (through the Acc trick used in extra_principles.v). 
       Thus, Bneigh_cont is equivalent to dialogue_cont_Brouwer.
       We prove this in
            Theorem Bneigh_cont_equiv_dialogue_cont_Brouwer.

       The underlying insight is: The existence of a Brouwer tree is equivalent to 
       the existence of an extensional tree that is inductively barred. 
       This equivalence only works in the Brouwer / Baire case, not in general.

 *)

(*We first define neighborhood functions and what it means to be
 continuous with respect to them.*)

Definition neighborhoodfunction (γ : list nat -> option nat) :=
  (forall α : nat -> nat, exists n : nat, γ (map α (iota 0 n)) <> None) /\
    forall a b : list nat, γ a <> None -> γ a = γ (a ++ b).


Definition neigh_realises γ (F : (nat -> nat) -> nat) :=
    forall α, exists m, γ (map α (iota 0 m)) = Some (F α) /\
              forall z, z < m -> γ (map α (iota 0 z)) = None.

Definition neigh_cont F :=
  exists γ, neighborhoodfunction γ /\ neigh_realises γ F.


(*A first result is that neighborhood functions are well-founded, valid
 Brouwer extensional trees.*)
Lemma neighborhood_wf_valid_Bext_tree (tau : list nat -> option nat) :
  neighborhoodfunction tau <-> (wf_Bext_tree tau /\ Bvalid_ext_tree tau).
Proof.
  split ; intros [Hwf Hval].
  - split.
    + intros alpha ; specialize (Hwf alpha) as [n Htau].
      exists n.
      destruct (tau [seq alpha i | i <- iota 0 n]) as [m | ]; [ | exfalso ; now apply Htau].
      exists m ; reflexivity.
    + intros alpha n m Heq.
      rewrite <- addn1, iotaD, map_cat.
      erewrite <- Hval ; [assumption |].
      now rewrite Heq.
  - split.
    + intros alpha ; specialize (Hwf alpha) as [n [o Hno]].
      exists n ; now rewrite Hno.
    + intros u v Hneq.
      induction v using last_ind ; [now rewrite cats0 |].
      rewrite <- cats1.
      destruct (tau u) ; [ | exfalso ; now apply Hneq].
      unfold Bvalid_ext_tree in *.
      specialize (Hval (from_pref 0 (u ++ v ++ [::x])) (size (u ++ v)) n).
      have Heq: (size (u ++ v ++ [:: x])) = ((size (u ++ v)).+1) by
        repeat erewrite size_cat ; cbn ; lia.
      symmetry ; etransitivity ; [ | apply Hval] ; unfold from_pref.
      * erewrite map_nth_iota0 ; [now rewrite <- Heq, take_size |].
        rewrite Heq ; now apply ltnSn.
      * erewrite map_nth_iota0 ; [ | rewrite Heq ; now apply leqnSn].
        rewrite catA take_size_cat => //.
Qed.

(*Moreover, the notion of a neighborhood function realising F is similar
 to the use of Beval_ext_tree, albeit the natural number n must be the smallest
 one in the case of neighborhood functions, while it can be any large enough
 natural number in the case of Beval_ext_tree_aux. *)
Lemma neigh_realises_Beval_aux (tau : seq nat -> option nat) a alpha l i :
  (exists n, 
      (tau (l ++ [seq alpha i | i <- iota i n]) = Some a /\
         (forall z : nat, z < n -> tau (l ++ [seq alpha i | i <- iota i z]) = None))) <->
    exists n, Beval_ext_tree_aux tau alpha n l i = Some a.
Proof.
  split.
  - intros [n Hyp] ; exists n ; revert l i Hyp.
    induction n ; intros l i [Hsome Hinfn]  ; [ now rewrite cats0 in Hsome | ].
    cbn ; remember (tau l) as aux ; destruct aux as [r | ].
    + specialize (Hinfn 0) ; rewrite cats0 in Hinfn.
      now rewrite Hinfn in Heqaux ; [inversion Heqaux | ].
    + eapply IHn ; split ; [ now rewrite cat_rcons | ].
      intros z Hinfz ; rewrite cat_rcons.
      now apply (Hinfn z.+1).
  - intros [n Heq].
    exists (Beval_ext_tree_trace_aux tau alpha n l i).
    rewrite Beval_ext_tree_map_aux in Heq.
    split ; [assumption | ].
    revert l i Heq ; induction n ; intros l i Heq z Hinf ; cbn in * ; [now inversion Hinf | ].
    remember (tau l) as aux ; destruct aux as [r | ] ; [inversion Hinf | ].
    destruct z ; cbn in * ; [now rewrite cats0 | rewrite - cat_rcons].
    apply IHn ; auto ; now rewrite cat_rcons.
Qed.


Lemma neigh_realises_Beval (tau : seq nat -> option nat) F :
  neigh_realises tau F <->
  forall alpha, exists n, Beval_ext_tree tau alpha n = Some (F alpha).
Proof.
  split.
  - intros Hyp alpha ; specialize (Hyp alpha) as [n [Hsome Hinfn]].
    eapply neigh_realises_Beval_aux ; now eauto.
  - intros Hyp alpha ; specialize (Hyp alpha) as [n Heq].
    eapply (neigh_realises_Beval_aux _ _ _ nil).
    now exists n.
Qed.

(*We now get to Result 1.*)

Theorem neigh_cont_Bseq_cont F :
  neigh_cont F <-> Bseq_cont_valid F.
Proof.
  split.
  - intros [tau [Hneigh Hreal]].
    exists tau ; split ; [ | now eapply neighborhood_wf_valid_Bext_tree].
    now apply neigh_realises_Beval.
  - intros [tau [Hcont Hval] ].
    exists tau ; split ; [ | now apply neigh_realises_Beval].
    eapply neighborhood_wf_valid_Bext_tree.
    split ; [ | assumption].
    intros alpha ; specialize (Hcont alpha) as [n Heq].
    exists (Beval_ext_tree_trace_aux tau alpha n nil 0), (F alpha).
    now rewrite - (Beval_ext_tree_map_aux tau alpha n nil 0).
Qed.

(*Let us now define Brouwer_operation. As explained, it is 
 an inductive predicate on functions of type list nat -> option nat.*)

Inductive Brouwer_operation : (list nat -> option nat) -> Prop :=
| Bconst γ n : (forall a, γ a = Some n) -> Brouwer_operation γ
| Bsup γ : γ nil = None ->
           (forall n, Brouwer_operation (fun a => γ (n :: a))) ->
           Brouwer_operation γ.

(*Brouwer_operation lands in Prop but we can use decidability of 
 the result of γ applied to some list l to go from Prop to Type.
However, Brouwer_operation as it stands is too intensional.
 We thus start by defining Brouwer_operation_at, a variant of Brouwer_operation
 that does not require function extensionality.*)

Inductive Brouwer_operation_at : (list nat -> option nat) -> list nat -> Prop :=
| Bconst_at l γ n : (forall a, γ (l ++ a) = Some n) -> Brouwer_operation_at γ l
| Bsup_at l γ : γ l = None ->
           (forall n, Brouwer_operation_at γ (rcons l n)) ->
           Brouwer_operation_at γ l.

(*Using Function Extensionality, the two predicates are equivalent.*)

Require Import FunctionalExtensionality.

Lemma Brouwer_operation_at_spec l γ :
  Brouwer_operation (fun a => γ (l ++ a)) <->
  Brouwer_operation_at γ l.
Proof.
  split.
  - intros H.
    remember (fun a : seq nat => γ (l ++ a)) as γ_l.
    revert l Heqγ_l.
    induction H.
    + intros l ->.
      econstructor. eassumption.
    + intros l ->.
      rewrite cats0 in H.
      eapply Bsup_at => //.
      intros. eapply H1.
      eapply functional_extensionality_dep_good.
      intros. now rewrite cat_rcons.
  - induction 1.
    + eapply Bconst => //.
    + eapply Bsup.
      1: rewrite cats0 => //.
      intros.
      erewrite functional_extensionality_dep_good.
      1: eapply H1.
      intros. cbn. rewrite cat_rcons => //.
Qed.

(*We now define Brouwer_operation_at', similar to Brouwer_operation but with only
 one constructor, to be able to escape Prop.*)

Inductive Brouwer_operation_at' (γ : list nat -> option nat) (l : list nat) : Prop :=
| Bsup_at' : (γ l = None \/ ~ (exists n, forall a, γ (l ++ a) = Some n) ->
                (forall n, Brouwer_operation_at' γ (rcons l n))) ->
                Brouwer_operation_at' γ l.

(*Brouwer_operation_at_Type is similar to Brouwer_operation_at', but lives in Type.*)
Inductive Brouwer_operation_at_Type (γ : list nat -> option nat) (l : list nat) : Type :=
| Bsup_at_Type : (γ l = None ->
              (forall n, Brouwer_operation_at_Type γ (rcons l n))) ->
             Brouwer_operation_at_Type γ l.

(*As expected, we can go from Brouwer_operation_at to Brouwer_operation_at'.*)
Lemma Brouwer_operation_at'_spec1 γ l :
  Brouwer_operation_at γ l -> Brouwer_operation_at' γ l.
Proof.
  (* split. *)
  - induction 1.
    + econstructor. intros [Hnone | Hnex].
      * enough (None = Some n) by congruence.
        rewrite <- Hnone. erewrite <- H.
        erewrite cats0 => //.
      * exfalso ; apply Hnex.
        exists n ; now auto.
    + econstructor. intros. eauto.
Qed.

(*And we can go from Brouwer_operation_at' to Brouwer_operation_at_Type*)
Lemma Brouwer_operation_at_Type_spec γ l :
  Brouwer_operation_at' γ l -> Brouwer_operation_at_Type γ l.
Proof.
  (* split. *)
  - induction 1.
    econstructor. auto.
Qed.


(*We now define Brouwer operation continuity.*)
Definition Bneigh_cont F :=
  exists γ, Brouwer_operation_at γ nil /\ neigh_realises γ F.

(*Functions that are Brouwer operations are neighborhood functions.*)
Lemma K0K_aux γ l :
  Brouwer_operation_at γ l ->
  (forall α : nat -> nat, exists n : nat, γ (l ++ (map α (iota 0 n))) <> None) /\
    forall a b : list nat, γ (l ++ a) <> None -> γ (l ++ a) = γ (l ++ a ++ b).
Proof.
  induction 1.
  - split.
    + intros. exists 0. congruence.
    + congruence.
  - split. 
    + intros α. destruct (H1 (α 0)) as [H1' H2'].
      * destruct (H1' (fun n => α (S n))) as [n].
        exists (1 + n).
        rewrite iotaD.
        cbn.
        replace 1 with (1 + 0). 
        1: rewrite iotaDl.
        2: now rewrite addn0.
        now rewrite - map_comp - cat_rcons .
    + intros a b Ha.
      destruct a. 1: rewrite cats0 in Ha ; congruence.
      destruct (H1 n) as [H1' H2'].
      rewrite catA - cat_rcons - catA.
      eapply H2'.
      rewrite cat_rcons ; congruence.
Qed.

Lemma K0K γ :
  Brouwer_operation_at γ nil ->
  neighborhoodfunction γ.
Proof.
  unfold neighborhoodfunction.
  now apply K0K_aux.
Qed.

(*Hence, Brouwer operation continuity implies neighborhood function continuity.*)

Lemma Bneigh_continuous_neigh_continuous F :
  Bneigh_cont F -> neigh_cont F.
Proof.
  intros (γ & H1 % K0K & H2).
  firstorder.
Qed.

(*We now turn to Result 2, the fact that Brouwer operation continuity is equivalent
 to Brouwer trees continuity.*)

Theorem Bneigh_cont_equiv_dialogue_cont_Brouwer F :
  Bneigh_cont F <-> dialogue_cont_Brouwer F.
Proof.
  split.
  - intros (γ & H1 & H2).
    have Hvalid := Bvalid_Bvalid2 ((neighborhood_wf_valid_Bext_tree _).1 (K0K H1)).2.
    eapply Brouwer_operation_at'_spec1 in H1.
    eapply Brouwer_operation_at_Type_spec in H1.
    unshelve eexists.
    + induction H1.
      destruct (γ l) eqn:E.
      -- eapply spit. exact n.
      -- eapply bite. intros n.
         eapply (X (erefl) n).
    + cbn.
      set (Brouwer_operation_at_Type_rect _) as f ; cbn in *.
      intros α.
      destruct (H2 α) as (m & Hm & Hinfm).
      erewrite beval_beval' ; unfold beval'.
      revert H1 α m Hinfm Hm.
      suff: forall l (H1 : Brouwer_operation_at_Type γ l) (α : nat -> nat) (m : nat)
                   (Hinfz : forall z : nat, z < m ->
                                            γ (l ++ [seq α i | i <- iota (size l) z]) = None),
          γ (l ++ [seq α i | i <- iota (size l) m]) = Some (F α) ->
          F α = beval_aux (f l H1) α (size l) by (intros Hyp ; eapply Hyp).
      intros l H1.
      induction H1 as [ l k IHk ] ; intros α m Hinfz Hm.
      generalize (@erefl _ (γ l)) ; generalize (γ l) at 2.
      intros aux Heqaux ; destruct aux as [n | ] ; cbn.
      * destruct m ; [rewrite cats0 in Hm | specialize (Hinfz 0) ; rewrite cats0 in Hinfz].
        -- now symmetry in Hm ; destruct Hm.
        -- now rewrite Hinfz in Heqaux ; [inversion Heqaux | ].
      * symmetry in Heqaux ; destruct Heqaux ; cbn.
        erewrite IHk with erefl (α (size l)) α m.-1 ; rewrite size_rcons ; auto.
        -- intros z Hinf ; rewrite cat_rcons.
           change (γ (l ++ [seq α i | i <- iota (size l) z.+1]) = None).
           apply Hinfz ; now destruct m ; [inversion Hinf | ].
        -- destruct m ; cbn in * ; [ | now rewrite cat_rcons].
           rewrite cats0 ; rewrite cats0 in Hm ; now eapply Hvalid.
  - intros [b Hb].
    unshelve eexists.
    + clear F Hb. induction b.
      * intros [].
        -- exact None.
        -- exact (Some r).
      * intros [].
        -- exact None.
        -- eapply (H n l).
    + split.
      * clear F Hb.
        generalize (@nil nat) as l.
        induction b as [ | k IHk] ; intros.
        -- cbn in *.
           destruct l ; [ econstructor 2 | econstructor ] ; cbn ; eauto.
           intros n ; econstructor ; eauto ; intros a ; now eauto.
        -- revert IHk ; remember (Btree_rec _ _) as f ; intros IHk.
           destruct l as [ | a l] ; auto.
           ++ econstructor 2 ; [ rewrite Heqf ; auto | ].
              intros n.
              specialize (IHk n nil).
              rewrite Heqf ; cbn ; rewrite - Heqf.
              remember (f (k n)) as tau.
              induction IHk as [ l tau m Hsome | l tau Hnone _ IHk].
              ** econstructor ; intros u ; cbn ; rewrite - Heqtau ; now apply Hsome. 
              ** econstructor 2 ; cbn ; [now rewrite - Heqtau | ].
                 intros m ; now eapply IHk.
           ++ rewrite Heqf ; cbn ; rewrite - Heqf.
              specialize (IHk a l).
              remember (f (k a)) as tau.
              induction IHk as [ l tau m Hsome | l tau Hnone _ IHk].
              ** econstructor ; intros u ; cbn ; rewrite - Heqtau ; now apply Hsome.
              ** econstructor 2 ; cbn ; [now rewrite - Heqtau | ].
                 intros m ; now apply IHk.
      * intros alpha.
        set (f := Btree_rec _ _).
        suff: exists m, f b [seq alpha i | i <- iota 0 m] = Some (beval b alpha) /\
                          (forall z : nat, z < m -> f b [seq alpha i | i <- iota 0 z] = None).
        { intros [m [Hm1 Hm2]] ; exists m ; split ; [ now erewrite Hb | auto]. }
        clear F Hb.
        revert alpha.
        induction b ; intros.
        -- exists 1 ; split ; cbn ; auto.
           intros z eqz.
           destruct z ; cbn ; [auto | inversion eqz].
        -- have auxil : forall  (m n : nat) (f : nat -> nat),
               [seq f i | i <- iota n.+1 m] = [seq (f \o succn) i | i <- iota n m].
           { clear.
             induction m ; cbn in * ; auto.
             intros n f ; f_equal.
             now erewrite <- IHm.
           }
           specialize (H (alpha 0) (alpha \o succn)) as [m [Hm1 Hm2]].
           rewrite - Hm1.
           exists m.+1 ; split ; auto.
           ++ cbn ; now erewrite auxil.
           ++ intros z Hinfz.
              case: (leqP m z) ; intros Hinfz'.
              ** destruct z ; cbn ; [reflexivity | ].
                 now rewrite - (Hm2 z) ; [now rewrite auxil | ].
              ** destruct z ; cbn ; [reflexivity | ].
                 rewrite - (Hm2 z) ; [now rewrite auxil | ].
                 now apply ltnW.
Qed.                 
