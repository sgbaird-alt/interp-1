function five = correctdis(five)

%% convert to disorientation (for plotting)
qtemp = disorientation(vertcat(five.q),'cubic');

dtemp = q2rod(qtemp);

t = num2cell(qtemp,2);
[five.q] = t{:};

t = num2cell(dtemp,2);
[five.d] = t{:};

end