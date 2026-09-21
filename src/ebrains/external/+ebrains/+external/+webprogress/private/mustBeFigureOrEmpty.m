function mustBeFigureOrEmpty(fig)
%mustBeFigureOrEmpty - Validate that a value is a figure or empty
%   mustBeFigureOrEmpty(FIG) raises an error unless FIG is empty or a
%   scalar figure handle.

    if isempty(fig)
        return
    end

    if ~(isscalar(fig) && isgraphics(fig, 'figure'))
        error('webprogress:validators:InvalidFigure', ...
            'Figure must be a scalar figure handle or empty.')
    end
end
