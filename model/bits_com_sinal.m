function b = bits_com_sinal(faixa)
% BITS_COM_SINAL  Menor largura, em complemento de dois, que contem [min max].
%   b = bits_com_sinal([vmin vmax]): menor b com -2^(b-1) <= vmin e
%   vmax <= 2^(b-1) - 1.
    vmin = min(faixa); vmax = max(faixa);
    b = 1;
    while vmin < -2^(b-1) || vmax > 2^(b-1) - 1
        b = b + 1;
    end
end
