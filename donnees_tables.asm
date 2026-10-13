; =====================================================================
;  donnees_tables.asm - tables precalculees
;  FICHIER GENERE PAR outils/generer_tables.py - NE PAS EDITER A LA MAIN
; =====================================================================

; numero de case officiel (1..50) -> index plateau. Indexe par n-1.
num_vers_idx:
        .byte $0E,$10,$12,$14,$16,$19,$1B,$1D,$1F,$21
        .byte $26,$28,$2A,$2C,$2E,$31,$33,$35,$37,$39
        .byte $3E,$40,$42,$44,$46,$49,$4B,$4D,$4F,$51
        .byte $56,$58,$5A,$5C,$5E,$61,$63,$65,$67,$69
        .byte $6E,$70,$72,$74,$76,$79,$7B,$7D,$7F,$81

; index plateau (0..143) -> numero de case, 0 si case non jouable.
idx_vers_num:
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$00,$01,$00,$02,$00,$03,$00,$04,$00,$05,$00
        .byte $00,$06,$00,$07,$00,$08,$00,$09,$00,$0A,$00,$00
        .byte $00,$00,$0B,$00,$0C,$00,$0D,$00,$0E,$00,$0F,$00
        .byte $00,$10,$00,$11,$00,$12,$00,$13,$00,$14,$00,$00
        .byte $00,$00,$15,$00,$16,$00,$17,$00,$18,$00,$19,$00
        .byte $00,$1A,$00,$1B,$00,$1C,$00,$1D,$00,$1E,$00,$00
        .byte $00,$00,$1F,$00,$20,$00,$21,$00,$22,$00,$23,$00
        .byte $00,$24,$00,$25,$00,$26,$00,$27,$00,$28,$00,$00
        .byte $00,$00,$29,$00,$2A,$00,$2B,$00,$2C,$00,$2D,$00
        .byte $00,$2E,$00,$2F,$00,$30,$00,$31,$00,$32,$00,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; adresse ecran du coin haut-gauche de la case n (poids faible).
case_adr_lo:
        .byte $A7,$B1,$BB,$C5,$CF,$42,$4C,$56,$60,$6A
        .byte $E7,$F1,$FB,$05,$0F,$82,$8C,$96,$A0,$AA
        .byte $27,$31,$3B,$45,$4F,$C2,$CC,$D6,$E0,$EA
        .byte $67,$71,$7B,$85,$8F,$02,$0C,$16,$20,$2A
        .byte $A7,$B1,$BB,$C5,$CF,$42,$4C,$56,$60,$6A

; adresse ecran du coin haut-gauche de la case n (poids fort).
case_adr_hi:
        .byte $80,$80,$80,$80,$80,$81,$81,$81,$81,$81
        .byte $81,$81,$81,$82,$82,$82,$82,$82,$82,$82
        .byte $83,$83,$83,$83,$83,$83,$83,$83,$83,$83
        .byte $84,$84,$84,$84,$84,$85,$85,$85,$85,$85
        .byte $85,$85,$85,$85,$85,$86,$86,$86,$86,$86

; adresse du debut de la ligne ecran y (poids faible).
lignes_lo:
        .byte $00,$50,$A0,$F0,$40,$90,$E0,$30,$80,$D0,$20,$70,$C0
        .byte $10,$60,$B0,$00,$50,$A0,$F0,$40,$90,$E0,$30,$80

; adresse du debut de la ligne ecran y (poids fort).
lignes_hi:
        .byte $80,$80,$80,$80,$81,$81,$81,$82,$82,$82,$83,$83,$83
        .byte $84,$84,$84,$85,$85,$85,$85,$86,$86,$86,$87,$87

; valeur de position d'un pion blanc, case 1 a 50. Pour un pion
;  noir sur la case n, lire l'entree de la case 51-n.
bonus_pion:
        .byte $12,$14,$14,$14,$12,$10,$12,$12,$12,$10
        .byte $0E,$10,$10,$10,$0E,$0C,$0E,$0E,$0E,$0C
        .byte $0A,$0C,$0C,$0C,$0A,$08,$0A,$0A,$0A,$08
        .byte $06,$08,$08,$08,$06,$04,$06,$06,$06,$04
        .byte $02,$04,$04,$04,$02,$03,$05,$05,$05,$03

; valeur de position d'une dame blanche, meme symetrie.
bonus_dame:
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        .byte $00,$04,$04,$04,$00,$00,$04,$04,$04,$00
        .byte $00,$04,$04,$04,$00,$00,$04,$04,$04,$00
        .byte $00,$04,$04,$04,$00,$00,$04,$04,$04,$00
        .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00

; hachage Zobrist : (type de piece - 1) * 50 + (case - 1).
zobrist_lo:
        .byte $D7,$97,$B8,$3B,$69,$15,$F1,$81,$12,$29
        .byte $4D,$41,$55,$94,$A1,$C1,$B3,$52,$BB,$ED
        .byte $1E,$C7,$16,$20,$EC,$A9,$88,$21,$D4,$6B
        .byte $E4,$A1,$FA,$3E,$01,$1E,$8F,$82,$17,$B0
        .byte $DE,$29,$3B,$69,$C4,$81,$99,$B5,$42,$3E
        .byte $04,$5F,$1A,$5B,$5C,$F5,$48,$A0,$67,$5B
        .byte $6B,$0A,$55,$45,$4D,$5E,$6D,$13,$54,$C5
        .byte $F8,$E1,$29,$5D,$C4,$AE,$FB,$C0,$7C,$A9
        .byte $DF,$8B,$FD,$D6,$87,$C2,$18,$DD,$E4,$65
        .byte $58,$C8,$90,$2B,$7C,$C0,$7F,$BB,$F1,$95
        .byte $BB,$34,$DE,$9E,$3A,$86,$43,$E5,$7F,$66
        .byte $37,$CB,$A4,$34,$F3,$36,$57,$06,$1A,$6B
        .byte $9E,$EB,$3E,$04,$97,$49,$74,$61,$99,$EB
        .byte $4A,$7A,$78,$B0,$81,$CA,$47,$41,$7E,$DE
        .byte $5D,$AF,$75,$FC,$B1,$64,$B8,$42,$B5,$64
        .byte $81,$40,$26,$D6,$54,$56,$77,$09,$C3,$19
        .byte $BE,$F6,$50,$41,$52,$A6,$82,$16,$25,$3C
        .byte $E9,$E2,$66,$78,$74,$3D,$E6,$84,$00,$6C
        .byte $2A,$49,$19,$60,$39,$C7,$16,$51,$68,$0B
        .byte $1E,$FF,$05,$64,$90,$6F,$26,$81,$36,$CB

; hachage Zobrist, poids fort.
zobrist_hi:
        .byte $13,$B4,$23,$BD,$9B,$EA,$2F,$2E,$8C,$C8
        .byte $20,$3E,$8D,$FC,$E2,$41,$51,$8C,$77,$87
        .byte $C5,$59,$B7,$4B,$F1,$74,$C4,$DE,$F9,$11
        .byte $4A,$EA,$54,$B6,$12,$8C,$EB,$06,$03,$D8
        .byte $D0,$48,$C1,$BB,$5F,$F1,$61,$4C,$98,$CE
        .byte $AC,$8F,$35,$4A,$9C,$BD,$83,$6E,$87,$6B
        .byte $09,$15,$9E,$10,$5D,$62,$55,$04,$44,$E0
        .byte $65,$A6,$A0,$93,$59,$32,$84,$AA,$7E,$7B
        .byte $E6,$78,$79,$8B,$99,$44,$BA,$8C,$6C,$9E
        .byte $A4,$39,$31,$97,$60,$50,$2B,$D4,$43,$CF
        .byte $0E,$95,$E5,$1E,$23,$FC,$D2,$D5,$56,$EE
        .byte $4D,$52,$26,$13,$C5,$C2,$16,$8D,$8E,$C4
        .byte $8F,$E5,$CE,$C0,$3D,$11,$55,$C7,$2C,$1B
        .byte $E0,$03,$8D,$4E,$2D,$7C,$F0,$F5,$6F,$61
        .byte $54,$78,$ED,$8E,$AB,$1E,$06,$8C,$F8,$6A
        .byte $AD,$3D,$12,$FB,$23,$08,$13,$43,$31,$50
        .byte $E6,$7E,$76,$5E,$D7,$1B,$02,$CC,$B3,$B8
        .byte $BF,$BF,$BE,$1C,$05,$98,$8A,$AD,$D2,$B0
        .byte $90,$8D,$3E,$77,$19,$A6,$E7,$25,$0C,$DC
        .byte $63,$B7,$0F,$B4,$08,$5F,$31,$3C,$CC,$C9

; debut de chaque type de piece dans la table Zobrist.
zob_base:
        .byte $00,$32,$64,$96

; valeur ajoutee quand les Noirs sont au trait
zob_trait:
        .byte $3A,$4F
