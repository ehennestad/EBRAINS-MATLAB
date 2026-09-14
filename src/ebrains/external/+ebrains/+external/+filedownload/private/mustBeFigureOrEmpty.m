function mustBeFigureOrEmpty(fig)
    if isempty(fig)
        return
    end

    if ~(isscalar(fig) && isgraphics(fig, 'figure'))
        error('filedownload:invalidFigure', ...
            'Figure must be a scalar figure handle or empty.')
    end
end
